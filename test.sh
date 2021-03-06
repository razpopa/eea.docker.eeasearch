#!/bin/bash

set -e

echo "Starting test..."
COMPOSEFILE_1="./test/docker-compose-smoketest.yml"
CONTAINERNAME_1="test_test1_1"
TESTNAME_1="[Basic app tests]"

COMPOSEFILE_2="./test/docker-compose-noargstest.yml"
CONTAINERNAME_2="test_test2_1"
TESTNAME_2="[No es_host set tests]"

COMPOSEFILE_3="./test/docker-compose-crontab.yml"
CONTAINERNAME_3="test_test3_1"
TESTNAME_3="[Sync JOB Tests]"

function print_test_header {
    printf "%-50s" "--> [TEST] $1 ..."
}

# Build images from a composefile and run
function test_build_and_start {
    print_test_header "Image build $2"
    docker-compose -f $1 build &> /dev/null
    echo "[OK]"

    print_test_header "Image start $2"
    docker-compose -f $1 up -d &> /dev/null
    echo "[OK]"

    sleep 2
}

# Clean images from a composefile and remove container
function cleanup {
    print_test_header "Cleanup $2"
    docker-compose -f $1 stop &> /dev/null
    docker-compose -f $1 rm --force &>/dev/null
    echo "[OK]"
}

# Get container id from container name
function get_container_id {
    docker ps -a | grep "$1\s*$" | awk '{ print  $1 }'
}

# Runserver basic functionality
###############################
rm -f index.html
test_build_and_start "$COMPOSEFILE_1" "$TESTNAME_1"
CONTAINER=$(get_container_id $CONTAINERNAME_1)

# Test that app is running
print_test_header "Image running"
docker ps | grep -q "^$CONTAINER"
echo "[OK]"

# Test app responds with correct title on port 3000
print_test_header "HTTP server responds"
wget -q localhost:3000
grep -q "<title>EEA Advanced search &mdash; Global catalogue</title>" index.html
rm index.html
echo "[OK]"

# Test api endpoint is enabled
print_test_header "API endpoint enabled"
wget -q localhost:3000/api/
rm index.html
echo "[OK]"

cleanup "$COMPOSEFILE_1" "$TESTNAME_1"
######################################

# No elastic host error
#######################
test_build_and_start "$COMPOSEFILE_2" "$TESTNAME_2"
CONTAINER=$(get_container_id $CONTAINERNAME_2)

# Test that container is stopped
print_test_header "Image stopped with no \$elastic_host"
docker ps -a | grep "^$CONTAINER" | grep -q "Exited"
echo "[OK]"

cleanup "$COMPOSEFILE_2" "$TESTNAME_2"

# SYNC crontab job tests
########################
test_build_and_start "$COMPOSEFILE_3" "$TESTNAME_3"
CONTAINER=$(get_container_id $CONTAINERNAME_3)

# Test that container is running
print_test_header "Image running with sync job enabled"
docker ps | grep -q "^$CONTAINER"
echo "[OK]"

# Test that container logged that job was enabled
print_test_header "Container logged sync job creation"
docker logs $CONTAINER 2>&1 | grep -i -q "enabled sync crontab job" &> /dev/null
echo "[OK]"

cleanup "$COMPOSEFILE_3" "$TESTNAME_3"

echo "--> [TEST] All tests passed!"
