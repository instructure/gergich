# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name                  = "gergich"
  s.version               = "1.0.0"
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

  s.add_dependency "httparty", "~> 0.16"
  s.add_dependency "sqlite3", "~> 1.3"

  s.add_development_dependency "rake", "~> 12.0"
  s.add_development_dependency "rspec", "~> 3.5"
  s.add_development_dependency "rubocop", "~> 0.49"
  s.add_development_dependency "simplecov", "~> 0.16.0"
end
