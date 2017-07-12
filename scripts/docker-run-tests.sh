#!/usr/bin/env bash

# Determine the appropriate github branch to clone using Travis environment variables
BRANCH=${TRAVIS_PULL_REQUEST_BRANCH:-$TRAVIS_BRANCH}
echo "BRANCH=$BRANCH"

docker exec -i devstack /bin/bash -s <<EOF

# Ensure that MySql is running.  Fixes error "Can't connect to MYSQL server on '127.0.0.1' (111)"
UP=$(/etc/init.d/mysql status | grep running | grep -v not | wc -l);
if [[ "$UP" -ne "1" ]]; then echo "Starting MySQL..."; systemctl start mysql.service; fi


# Ensure that Mongo is running
echo 'Fixing Mongo'
sudo -S rm /edx/var/mongo/mongodb/mongod.lock
sudo -S mongod -repair --config /etc/mongod.conf
sudo -S chown -R mongodb:mongodb /edx/var/mongo/.
sudo -S service mongod start
export LC_ALL=en_US.UTF-8
export PYTHONIOENCODING=UTF-8

locale

# Get the latest code
cd /edx/app/edxapp/edx-platform
git checkout $BRANCH
git pull


# Elevate priveleges to edxapp user
echo 'Run as edxapp user'
sudo su edxapp -s /bin/bash 
source /edx/app/edxapp/edxapp_env
cd /edx/app/edxapp/edx-platform


echo 'Running Tests'
echo $TEST_SUITE 
echo $SHARD 

# These variables are becoming unset inside docker container
export TEST_SUITE=$TEST_SUITE
export SHARD=$SHARD

# Run Firefox with xvfb on DISPLAY :1
export DISPLAY=:1
./scripts/generic-ci-tests.sh
EOF