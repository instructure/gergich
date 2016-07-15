#!/bin/bash

set -e

echo "building..."
docker-compose build

echo "running tests..."
exit_code=0
docker-compose run --name test_coverage test || exit_code=$?

echo "copying coverage data..."
docker cp test_coverage:/app/coverage coverage

echo "cleaning up..."
docker rm test_coverage
exit $exit_code
