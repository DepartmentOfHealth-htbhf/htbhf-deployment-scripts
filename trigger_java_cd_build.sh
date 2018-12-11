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

REQUEST_BODY='{
  "request": {
    "branch": "master",
    "config": {
      "env": {
        "APP_URL": "'${APP_URL}'",
        "MANIFEST_URL": "'${MANIFEST_URL}'",
        "APP_NAME": "'${APP_NAME}'",
        "CF_DOMAIN": "'${CF_DOMAIN}'"
      }
    }
  }
}'

curl -s -X POST \
   -H "Content-Type: application/json" \
   -H "Accept: application/json" \
   -H "Travis-API-Version: 3" \
   -H "Authorization: token zKqvM4sQf4mczbn0mvARzw" \
   -d "${REQUEST_BODY}" \
   https://api.travis-ci.com/repo/DepartmentOfHealth-htbhf%2Fhtbhf-continous-delivery/requests