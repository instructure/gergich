#!/bin/bash

set -e

echo "building..."
docker-compose build

cleanup() {
  echo "cleaning up..."
  docker rm test_coverage > /dev/null
}

trap cleanup EXIT

echo "running tests..."
exit_code=0
docker-compose run --name test_coverage test || exit_code=$?

echo "copying coverage data..."
docker cp test_coverage:/usr/src/app/coverage coverage

exit $exit_code
