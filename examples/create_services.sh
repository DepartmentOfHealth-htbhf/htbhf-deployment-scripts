#!/bin/bash

# script to provision a new environment (staging, for example)
# note that instance sizes might need to be changed
# this script is not run as part of any automated process - trigger it manually if required

check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty"
        exit 1
    fi
}
 # check necessary environment variables are set and not empty
check_variable_is_set CF_SPACE
check_variable_is_set CF_API
check_variable_is_set CF_ORG
check_variable_is_set CF_USER
check_variable_is_set CF_PASS
check_variable_is_set BASIC_AUTH_USER
check_variable_is_set BASIC_AUTH_PASS
check_variable_is_set CF_PUBLIC_DOMAIN # london.cloudapps.digital

cf_login

echo "Creating service help-to-buy-healthy-foods-redis"
cf create-service redis tiny-clustered-3.2 help-to-buy-healthy-foods-redis

echo "Creating service htbhf-claimant-service-postgres"
cf create-service postgres small-ha-10.5 htbhf-claimant-service-postgres

# if we're in production then the web ui will have no environment suffix
SPACE_SUFFIX="-${CF_SPACE}"
if [[ ${CF_SPACE} == 'production' ]]; then
	SPACE_SUFFIX=''
fi

WEB_UI_APP_NAME=help-to-buy-healthy-foods${SPACE_SUFFIX}

EXISTING_WEB_UI=$(cf apps | grep "${WEB_UI_APP_NAME} ")
if [[ -z ${EXISTING_WEB_UI} ]]; then
	echo "Creating holding page application '${WEB_UI_APP_NAME}' in order to apply basic auth route"
	mkdir tmp-holding-page
	cd tmp-holding-page
	echo "<html>\n<head>\n<title>${WEB_UI_APP_NAME}</title>\n</head>\n<body>\n<p>Temporary holding page</p>\n</body>\n</html>" > index.html
	echo "---\napplications:\n- name: ${WEB_UI_APP_NAME}\n  memory: 64M\n  buildpack: staticfile_buildpack" > manifest.yml
	cf push
	cd ..
	rm -rf tmp-holding-page
fi

echo "Creating route to secure web ui with basic auth"
mkdir tmp-basic-auth-route
cd tmp-basic-auth-route
git clone https://github.com/alext/cf_basic_auth_route_service .
cf push ${WEB_UI_APP_NAME}-route --no-start
cf set-env ${WEB_UI_APP_NAME}-route AUTH_USERNAME ${BASIC_AUTH_USER}
cf set-env ${WEB_UI_APP_NAME}-route AUTH_PASSWORD ${BASIC_AUTH_PASS}
cf start ${WEB_UI_APP_NAME}-route
cf create-user-provided-service ${WEB_UI_APP_NAME}-route -r https://${WEB_UI_APP_NAME}-route.${CF_PUBLIC_DOMAIN}
cf bind-route-service ${CF_PUBLIC_DOMAIN} ${WEB_UI_APP_NAME}-route --hostname ${WEB_UI_APP_NAME}
cd ..
rm -rf tmp-basic-auth-route