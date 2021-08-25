# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

RSpec::Core::RakeTask.new

task(default: %i[spec rubocop])

# rake rubocop
RuboCop::RakeTask.new
