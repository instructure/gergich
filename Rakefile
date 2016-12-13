require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new

task(default: [:spec, :rubocop])
task(test: :spec)

# rake rubocop
RuboCop::RakeTask.new do |task|
  task.options = ["-D"]
end

# alias for rubocop task
task(cop: [:rubocop])
