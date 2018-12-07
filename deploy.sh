#!/bin/bash

export PATH=$PATH:${BIN_DIR}

check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty"
        exit 1
    fi
}
 # check necessary environment variables are set and not empty
check_variable_is_set APP_NAME
check_variable_is_set APP_PATH
check_variable_is_set BIN_DIR
check_variable_is_set CF_SPACE
check_variable_is_set CF_API
check_variable_is_set CF_ORG
check_variable_is_set CF_USER
check_variable_is_set CF_PASS
check_variable_is_set CF_DOMAIN
check_variable_is_set CF_PUBLIC_DOMAIN
check_variable_is_set PROTOCOL
check_variable_is_set SMOKE_TESTS

/bin/bash ${BIN_DIR}/install_cf_cli.sh;

source ${BIN_DIR}/cf_deployment_functions.sh

APP_FULL_NAME="$APP_NAME-$CF_SPACE"

echo "Logging into cloud foundry with api:$CF_API, org:$CF_ORG, space:$CF_SPACE with user:$CF_USER"
cf login -a ${CF_API} -u ${CF_USER} -p "${CF_PASS}" -s ${CF_SPACE} -o ${CF_ORG}

echo "Deploying $APP_FULL_NAME to $CF_SPACE from $APP_PATH"

# if the app already exists, perform a blue green deployment, if not then a regular deployment
if cf app ${APP_FULL_NAME} >/dev/null 2>/dev/null; then
  perform_blue_green_deployment
else
  perform_first_time_deployment
fi