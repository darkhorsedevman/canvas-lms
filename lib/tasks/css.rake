namespace :css do
  desc "Generate styleguide"
  task :styleguide do
    puts "--> creating styleguide"
    system('bin/dress_code config/styleguide.yml')
    raise "error running dress_code" unless $?.success?
  end

  task :compile do
    require 'lib/brandable_css'
    puts "--> Starting: 'css:compile'"
    time = Benchmark.realtime do
      if (BrandConfig.table_exists? rescue false)
        Rake::Task['brand_configs:write'].invoke
      else
        puts "--> no DB connection, skipping generation of brand_config files"
      end
      BrandableCSS.save_default_files!
      raise "error running brandable_css" unless system('yarn run build:css')
    end
    puts "--> Finished: 'css:compile' in #{time}"
  end
end
