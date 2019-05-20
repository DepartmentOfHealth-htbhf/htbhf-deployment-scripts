#!/bin/bash

check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty"
        exit 1
    fi
}

check_variable_is_set APP_NAME
check_variable_is_set CF_DOMAIN
check_variable_is_set TRAVIS_AUTH_TOKEN

# get current version from package.json.
VERSION=$(sed -nE 's/^[ \\t]*"version": "([0-9]{1,}\.[0-9]{1,}\.[0-9x]{1,})",$/\1/p' package.json;)
# get the github repo url:
#   'git remote -v' lists all remote urls.
#   'grep fetch | grep origin' ensures we only read the correct remote.
#   The first sed extracts the url (after 'origin ' and before '.git').
#   The second ensures that we use the https variant if the repo was cloned using ssh.
GIT_REPO_URL=$(git remote -v | grep fetch | grep origin | sed -nE 's/^origin\s(.*)\.git.*$/\1/p' | sed 's~git@github.com:~https://~')
ZIP_URL="${GIT_REPO_URL}/archive/v${VERSION}.zip"
RUN_COMPATIBILITY_TESTS=${RUN_COMPATIBILITY_TESTS:-true}
RUN_PERFORMANCE_TESTS=${RUN_PERFORMANCE_TESTS:-true}
COMMIT_MESSAGE=$(echo -e "${TRAVIS_COMMIT_MESSAGE}" | tr -d '\n\r')

REQUEST_BODY='{
  "request": {
    "branch": "master",
    "message": "'${APP_NAME}': '${COMMIT_MESSAGE}'",
    "config": {
      "env": {
        "RUN_COMPATIBILITY_TESTS": "'${RUN_COMPATIBILITY_TESTS}'",
        "RUN_PERFORMANCE_TESTS": "'${RUN_PERFORMANCE_TESTS}'",
        "GITHUB_REPO_SLUG": "'${TRAVIS_REPO_SLUG}'",
        "TRAVIS_COMMIT_MESSAGE": "'${COMMIT_MESSAGE}'",
        "ZIP_URL": "'${ZIP_URL}'",
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
