#!/bin/bash

set -ex

bundle exec rubocop --fail-level autocorrect

ruby -v | egrep "^ruby 2\.6" && export COVERAGE=1

bundle exec rspec

# these actually hit gerrit; only run them in CI land (you can do it
# locally if you set all the docker-compose env vars)
if [[ "$GERRIT_PATCHSET_REVISION" ]]; then
  bundle exec gergich citest
  bundle exec master_bouncer check
  DRY_RUN=1 bundle exec master_bouncer check_all
  # ensure gergich works without .git directories
  rm -rf .git
  bundle exec gergich status
fi

bundle exec bin/check_coverage
