# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name                  = "gergich"
  s.version               = "2.2.1"
  s.summary               = "Command-line tool for adding Gerrit comments"
  s.description           = "Gergich is a little command-line tool for wiring up linters to " \
                            "Gerrit so you can get nice inline comments right on the review"
  s.authors               = ["Jon Jensen"]
  s.email                 = "jon@instructure.com"
  s.homepage              = "https://github.com/instructure/gergich"
  s.license               = "MIT"

  s.required_ruby_version = ">= 2.7"

  s.bindir = "exe"
  s.executables = %w[gergich master_bouncer]
  s.files = Dir["{exe,lib}/**/*"]

  s.add_dependency "httparty", "~> 0.17"
  s.add_dependency "sqlite3", ">= 1.4", "< 3.0"
  s.metadata["rubygems_mfa_required"] = "true"
end
