# This file was generated by the `rspec --init` command. Conventionally, all
# specs live under a `spec` directory, which RSpec adds to the `$LOAD_PATH`.
# Require this file using `require "spec_helper"` to ensure that it is only
# loaded once.
#
# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration

require 'simplecov'
require 'simplecov-rcov'

SimpleCov.command_name('activesupport-suspend-callback-gem')
SimpleCov.start do
  SimpleCov.coverage_dir('../../coverage')
  SimpleCov.use_merging
  SimpleCov.merge_timeout(10000)
  SimpleCov.at_exit {
    SimpleCov.result
  }
end

require "active_support/callbacks/suspension"

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'
end
