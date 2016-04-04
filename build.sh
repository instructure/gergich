#!/bin/bash

set -e

bundle install
bundle exec rspec
bundle exec rubocop
bin/gergich citest
