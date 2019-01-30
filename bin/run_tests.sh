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

# these actually hit gerrit; only run them in CI land (you can do it
# locally if you set all the docker-compose env vars)
if [[ "$GERRIT_PATCHSET_REVISION" ]]; then
  run_command bin/gergich citest
  run_command bin/master_bouncer check
  DRY_RUN=1 run_command bin/master_bouncer check_all
  # ensure gergich works without .git directories
  rm -rf .git
  run_command bin/gergich status
fi

run_command bin/check_coverage

clean_up_and_exit
