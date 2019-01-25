#!/bin/bash

check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty"
        exit 1
    fi
}

check_variable_is_set BINTRAY_ROOT_URL
check_variable_is_set APP_NAME
check_variable_is_set CF_DOMAIN

# version has already been incremented for the next build, so previousVersion is the version of the build just created.
VERSION=`cat version.properties | grep "previousVersion" | cut -d'=' -f2`
APP_URL=${BINTRAY_ROOT_URL}/${APP_NAME}/${VERSION}/${APP_NAME}-${VERSION}.jar
MANIFEST_URL=${BINTRAY_ROOT_URL}/${APP_NAME}-manifest/${VERSION}/${APP_NAME}-manifest-${VERSION}.jar
RUN_COMPATIBILITY_TESTS=${RUN_COMPATIBILITY_TESTS:-false}
RUN_PERFORMANCE_TESTS=${RUN_PERFORMANCE_TESTS:-true}

REQUEST_BODY='{
  "request": {
    "branch": "master",
    "config": {
      "env": {
        "RUN_COMPATIBILITY_TESTS": "'${RUN_COMPATIBILITY_TESTS}'",
        "RUN_PERFORMANCE_TESTS": "'${RUN_PERFORMANCE_TESTS}'",
        "GITHUB_REPO_SLUG": "'${TRAVIS_REPO_SLUG}'",
        "TRAVIS_COMMIT_MESSAGE": "'${TRAVIS_COMMIT_MESSAGE}'",
        "APP_URL": "'${APP_URL}'",
        "MANIFEST_URL": "'${MANIFEST_URL}'",
        "APP_NAME": "'${APP_NAME}'",
        "APP_VERSION": "'${VERSION}'",
        "CF_DOMAIN": "'${CF_DOMAIN}'"
      },
      "script": "cd_scripts/run.sh"
    }
  }
}'

echo "Request body: ${REQUEST_BODY}"

curl -s -X POST \
   -H "Content-Type: application/json" \
   -H "Accept: application/json" \
   -H "Travis-API-Version: 3" \
   -H "Authorization: token ${TRAVIS_AUTH_TOKEN}" \
   -d "${REQUEST_BODY}" \
   https://api.travis-ci.com/repo/DepartmentOfHealth-htbhf%2Fhtbhf-continous-delivery/requests
