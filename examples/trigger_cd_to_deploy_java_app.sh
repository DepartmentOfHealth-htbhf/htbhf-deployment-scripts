#!/bin/bash

check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty. ($2)"
        exit 1
    fi
}

check_variable_is_set APP_NAME "The name of the application to deploy. E.g. 'htbhf-claimant-service'"
check_variable_is_set APP_VERSION "The version to deploy. Should match the version number in Bintray, and exclude any leading 'v'."
check_variable_is_set TRAVIS_AUTH_TOKEN "The Travis-ci token. Available from travis-ci.com in my account -> settings."

GITHUB_REPO_SLUG=DepartmentOfHealth-htbhf/${APP_NAME}
BINTRAY_ROOT_URL=https://dl.bintray.com/departmentofhealth-htbhf/maven/uk/gov/dhsc/htbhf
APP_URL=${BINTRAY_ROOT_URL}/${APP_NAME}/${APP_VERSION}/${APP_NAME}-${APP_VERSION}.jar
MANIFEST_URL=${BINTRAY_ROOT_URL}/${APP_NAME}-manifest/${APP_VERSION}/${APP_NAME}-manifest-${APP_VERSION}.jar
COMMIT_MESSAGE="Manual deployment of ${APP_NAME} ${APP_VERSION}"

REQUEST_BODY='{
  "request": {
    "branch": "master",
    "config": {
      "env": {
        "RUN_COMPATIBILITY_TESTS": "false",
        "RUN_PERFORMANCE_TESTS": "false",
        "DEPLOY_TO_PROD": "true",
        "GITHUB_REPO_SLUG": "'${GITHUB_REPO_SLUG}'",
        "TRAVIS_COMMIT_MESSAGE": "'${COMMIT_MESSAGE}'",
        "APP_URL": "'${APP_URL}'",
        "MANIFEST_URL": "'${MANIFEST_URL}'",
        "APP_NAME": "'${APP_NAME}'",
        "APP_VERSION": "'${APP_VERSION}'",
        "CF_DOMAIN": "apps.internal"
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
