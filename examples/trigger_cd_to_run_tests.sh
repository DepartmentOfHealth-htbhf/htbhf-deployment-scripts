#!/bin/bash

check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty. ($2)"
        exit 1
    fi
}

check_variable_is_set TRAVIS_AUTH_TOKEN "The Travis-ci token. Available from travis-ci.com in my account -> settings."

COMMIT_MESSAGE="Manual run of tests"

REQUEST_BODY='{
  "request": {
    "branch": "master",
    "config": {
      "env": {
        "RUN_COMPATIBILITY_TESTS": "true",
        "RUN_PERFORMANCE_TESTS": "true",
        "DEPLOY_TO_PROD": "false",
        "GITHUB_REPO_SLUG": "",
        "TRAVIS_COMMIT_MESSAGE": "'${COMMIT_MESSAGE}'",
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
