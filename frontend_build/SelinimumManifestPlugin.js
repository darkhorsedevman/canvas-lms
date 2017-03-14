/*
 * Generate a mapping of modules -> entry points that contain them.
 *
 * Selinimum needs to know which entry point(s) a given js/jsx/coffee/hbs
 * file belongs to, so that it can figure out which tests it needs to run
 * for your commit.
 */

const fs = require('fs')
const path = require('path')

class SelinimumManifestPlugin {
  getEntrypointsByModule (stats) {
    // figure out the initial chunk(s) for all secondary chunks, so we can
    // work out which modules belong to each entry point
    const initialDependencies = {}
    const setInitialDependencies = (chunk, dependency) => {
      if (chunk.initial) {
        initialDependencies[chunk.id] = initialDependencies[chunk.id] || new Set()
        initialDependencies[chunk.id].add(dependency)
      } else {
        chunk.parents.forEach((parentId) => {
          setInitialDependencies(stats.chunks[parentId], dependency)
        })
      }
    }
    stats.chunks.forEach((chunk) => {
      if (!chunk.initial) setInitialDependencies(chunk, chunk.id)
    })

    const result = {}
    Object.keys(stats.entrypoints).forEach((entrypoint) => {
      const chunks = stats.entrypoints[entrypoint].chunks

      // vendor has one chunk, the rest have two (vendor and the bundle itself)
      const chunk = chunks.length === 1 ? chunks[0] : chunks[1]
      let chunksFrd = [chunk]

      // now grab chunk dependencies (if any)
      if (initialDependencies[chunk]) {
        chunksFrd = chunksFrd.concat(Array.from(initialDependencies[chunk]))
      }

      chunksFrd.forEach((chunkId) => {
        stats.chunks[chunkId].modules.forEach((module) => {
          // only frd files in the app, no node_modules or pitch loaders
          if (!module.name.match(/^\.\/[^~]/) || module.name.match(/!/)) return

          result[module.name] = result[module.name] || []
          result[module.name].push(entrypoint)
        })
      })
    })

    return result
  }

  apply (compiler) {
    compiler.plugin('emit', (compilation, done) => {
      const stats = compilation.getStats().toJson({chunkModules: true})
      const entrypointsByBundle = this.getEntrypointsByModule(stats)
      const manifestPath = path.join(compiler.options.output.path, 'selinimum-manifest.json')
      fs.writeFileSync(manifestPath, JSON.stringify(entrypointsByBundle))
      done()
    })
  }
}

module.exports = SelinimumManifestPlugin
