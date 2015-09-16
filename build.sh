#!/bin/bash

set -e

bundle install
bundle exec rspec
bin/gergich citest
