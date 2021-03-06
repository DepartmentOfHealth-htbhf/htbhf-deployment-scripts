#!/bin/bash

export PATH=$PATH:${SCRIPT_DIR}

check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty. ($2)"
        exit 1
    fi
}
 # check necessary environment variables are set and not empty
check_variable_is_set APP_NAME "The name of the app to deploy - this is the name of the app in cloud foundry"
check_variable_is_set APP_PATH "The path to the artefact - a jar file or the directory of a node app"
check_variable_is_set SCRIPT_DIR "The directory containing this script file"
check_variable_is_set CF_SPACE "The name of the space to set up services for"
check_variable_is_set CF_API "E.g. api.london.cloud.service.gov.uk"
check_variable_is_set CF_ORG "E.g. department-of-health-and-social-care)"
check_variable_is_set CF_USER "Your cloudfoundry username/email address"
check_variable_is_set CF_PASS "Your cloudfoundry password"
check_variable_is_set CF_DOMAIN "The domain to deploy the app to. E.g. either apps.internal or london.cloudapps.digital"
check_variable_is_set CF_PUBLIC_DOMAIN "E.g. london.cloudapps.digital"
check_variable_is_set SMOKE_TESTS "The script to run to confirm that the application is up and running. Will be passed an argument defining the url of the app."

/bin/bash ${SCRIPT_DIR}/install_cf_cli.sh;

source ${SCRIPT_DIR}/cf_deployment_functions.sh

cf_login

SPACE_SUFFIX="-${CF_SPACE}"
if [[ ${CF_SPACE} == 'production' ]]; then
	SPACE_SUFFIX=''
fi
export SPACE_SUFFIX

APP_FULL_NAME="${APP_NAME}${SPACE_SUFFIX}"

echo "Deploying $APP_FULL_NAME to $CF_SPACE from $APP_PATH"

# if the app already exists, perform a blue green deployment, if not then a regular deployment
if cf app ${APP_FULL_NAME} >/dev/null 2>/dev/null; then
  perform_blue_green_deployment
else
  perform_first_time_deployment
fi
