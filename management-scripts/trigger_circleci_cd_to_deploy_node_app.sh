#!/bin/bash

check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty. ($2)"
        exit 1
    fi
}

check_variable_is_set APP_NAME "The name of the application as deployed. E.g. 'help-to-buy-healthy-foods'"
check_variable_is_set APP_VERSION "The version to deploy. Should match the version in Github, but exclude the leading 'v'."
check_variable_is_set REPO_NAME "The name of the project in github. E.g. 'htbhf-applicant-web-ui'"
check_variable_is_set CIRCLECI_AUTH_TOKEN "The circle-ci token. Available from circle-ci.com in my account -> settings."

GITHUB_REPO_SLUG=DepartmentOfHealth-htbhf/${REPO_NAME}
ZIP_URL="https://github.com/${GITHUB_REPO_SLUG}/archive/v${APP_VERSION}.zip"

REQUEST_BODY='{
  "build_parameters": {
    "CD_BUILD":true,
    "RUN_COMPATIBILITY_TESTS": true,
    "RUN_PERFORMANCE_TESTS": true,
    "GITHUB_REPO_SLUG": "'${GITHUB_REPO_SLUG}'",
    "ZIP_URL": "'${ZIP_URL}'",
    "APP_NAME": "'${APP_NAME}'",
    "APP_VERSION": "'${APP_VERSION}'",
    "CF_DOMAIN": "london.cloudapps.digital"
  }
}'

curl -X POST -d "$REQUEST_BODY" \
    --header "Content-Type:application/json" \
    https://circleci.com/api/v1.1/project/gh/DepartmentOfHealth-htbhf/circle-ci-cd-test/tree/master?circle-token="$CIRCLECI_AUTH_TOKEN"
