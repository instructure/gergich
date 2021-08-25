# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name                  = "gergich"
  s.version               = "1.2.3"
  s.summary               = "Command-line tool for adding Gerrit comments"
  s.description           = "Gergich is a little command-line tool for wiring up linters to " \
                            "Gerrit so you can get nice inline comments right on the review"
  s.authors               = ["Jon Jensen"]
  s.email                 = "jon@instructure.com"
  s.executables           = %w[gergich master_bouncer]
  s.files                 = ["LICENSE", "README.md"] + Dir["**/*.rb"] + Dir["bin/*"]
  s.homepage              = "https://github.com/instructure/gergich"
  s.license               = "MIT"

  s.required_ruby_version = ">= 2.4.0"

  s.add_dependency "httparty", "~> 0.17"
  s.add_dependency "sqlite3", "~> 1.4"

  s.add_development_dependency "byebug", "~> 11.1"
  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "rspec", "~> 3.9"
  s.add_development_dependency "rubocop", "~> 0.79.0"
  s.add_development_dependency "simplecov", "~> 0.17.1"
end
