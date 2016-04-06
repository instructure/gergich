#!/bin/bash

set -e

function run_command {
  echo -e "\n[$@] STARTING $(date)"
  last_status=0
  "$@" || last_status=$?
  if [[ $last_status == 0 ]]; then
    echo -e "[$@] \033[32mOK\033[0m"
  else
    echo -e "[$@] \033[31mFAILED!\033[0m"
  fi
  echo -e "[$@] FINISHED $(date)\n"

  [[ $last_status == 0 ]] || clean_up_and_exit
}

function clean_up_and_exit {
  end_timestamp=$(date +%s)
  duration=$((end_timestamp-start_timestamp))

  if [[ $last_status != 0 ]]; then
    echo -e "\033[31mBUILD FAILED\033[0m in $duration seconds\n"
  else
    echo "BUILD PASSED in $duration seconds"
  fi
  exit $last_status
}

start_timestamp=$(date +%s)

run_command bundle exec rubocop

export COVERAGE=1

run_command bundle exec rspec
run_command bin/gergich citest

run_command bin/check_coverage

if [[ $GEMNASIUM_TOKEN && $GEMNASIUM_ENABLED ]]; then
  # Push our dependency specification files to gemnasium for analysis
  run_command gemnasium dependency_files push -f=gergich.gemspec
fi

clean_up_and_exit
