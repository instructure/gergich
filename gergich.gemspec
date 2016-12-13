Gem::Specification.new do |s|
  s.name                  = "gergich"
  s.version               = "0.1.10"
  s.summary               = "Command-line tool for adding Gerrit comments"
  s.description           = "Gergich is a little command-line tool for wiring up linters to " \
                            "Gerrit so you can get nice inline comments right on the review"
  s.authors               = ["Jon Jensen"]
  s.email                 = "jon@instructure.com"
  s.executables           = %w[gergich master_bouncer]
  s.files                 = ["LICENSE", "README.md"] + Dir["**/*.rb"] + Dir["bin/*"]
  s.homepage              = "https://github.com/instructure/gergich"
  s.license               = "MIT"

  s.required_ruby_version = ">= 1.9.3"

  s.add_dependency "sqlite3", "~> 1.3"
  s.add_dependency "httparty", "~> 0.6"

  s.add_development_dependency "rake"
  s.add_development_dependency "rspec", "~> 3.5"
  s.add_development_dependency "rubocop"
  s.add_development_dependency "simplecov"
end
