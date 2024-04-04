# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name                  = "gergich"
  s.version               = "2.1.4"
  s.summary               = "Command-line tool for adding Gerrit comments"
  s.description           = "Gergich is a little command-line tool for wiring up linters to " \
                            "Gerrit so you can get nice inline comments right on the review"
  s.authors               = ["Jon Jensen"]
  s.email                 = "jon@instructure.com"
  s.homepage              = "https://github.com/instructure/gergich"
  s.license               = "MIT"

  s.required_ruby_version = ">= 2.6"

  s.bindir = "exe"
  s.executables = %w[gergich master_bouncer]
  s.files = Dir["{exe,lib}/**/*"]

  s.add_dependency "httparty", "~> 0.17"
  s.add_dependency "sqlite3", "~> 1.4"

  s.add_development_dependency "byebug", "~> 11.1"
  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "rspec", "~> 3.9"
  s.add_development_dependency "rubocop", "~> 1.21"
  s.add_development_dependency "rubocop-rake", "~> 0.6"
  s.add_development_dependency "rubocop-rspec", "~> 2.5"
  s.add_development_dependency "simplecov", "~> 0.21.2"
end
