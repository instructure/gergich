#!/bin/bash

set -e

bundle install

bundle exec rubocop

export COVERAGE=1
rm -rf coverage

bundle exec rspec
bin/gergich citest

bin/check_coverage
