#!/bin/bash

# script to provision a new environment (staging, for example)
# it is assumed that the new space has already been created via the dashboard
# note that instance sizes might need to be changed
# this script is not run as part of any automated process - trigger it manually if required

check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty. ($2)"
        exit 1
    fi
}

pause(){
    read -p "Press [Enter] key to continue..."
}

 # check necessary environment variables are set and not empty
 # please ensure any changes to required variables are also updated in README.md
check_variable_is_set CF_SPACE "The name of the space to set up services for"
check_variable_is_set CF_API "E.g. api.london.cloud.service.gov.uk"
check_variable_is_set CF_ORG "E.g. department-of-health-and-social-care)"
check_variable_is_set CF_USER "Your cloudfoundry username/email address"
check_variable_is_set CF_PASS "Your cloudfoundry password"
check_variable_is_set BASIC_AUTH_USER "Username for basic authentication of the applicant web ui"
check_variable_is_set BASIC_AUTH_PASS "Password for basic authentication of the applicant web ui"
check_variable_is_set CF_PUBLIC_DOMAIN "E.g. london.cloudapps.digital"
check_variable_is_set LOGIT_ENDPOINT "See https://docs.cloud.service.gov.uk/monitoring_apps.html#configure-app"
check_variable_is_set LOGIT_PORT "See https://docs.cloud.service.gov.uk/monitoring_apps.html#configure-app"
check_variable_is_set GA_TRACKING_ID "The google analytics tracking id"
check_variable_is_set UI_LOG_LEVEL "E.g. info"

source ../cf_deployment_functions.sh

cf_login

if cf service help-to-buy-healthy-foods-redis >/dev/null 2>/dev/null; then
    echo "help-to-buy-healthy-foods-redis already exists"
else
    echo ""
    PS3="Select the size of the redis service: "
    redisSizes=("tiny-3.2" "medium-ha-3.2")
    select redisSize in "${redisSizes[@]}"
    do
        case redisSize in
            *) break;;
        esac
    done

    echo "Creating ${redisSize} Redis service help-to-buy-healthy-foods-redis"
    echo "cf create-service redis ${redisSize} help-to-buy-healthy-foods-redis"
    cf create-service redis ${redisSize} help-to-buy-healthy-foods-redis
    pause
fi

if cf service htbhf-claimant-service-postgres >/dev/null 2>/dev/null; then
    echo "htbhf-claimant-service-postgres already exists"
else
    echo -e "\n"
    PS3="Select the size of the postgres service: "
    postgresSizes=("small-10.5" "small-ha-10.5" "medium-10.5" "medium-ha-10.5" "large-10.5" "large-ha-10.5" "xlarge-10.5" "xlarge-ha-10.5")
    select postgresSize in "${postgresSizes[@]}"
    do
        case postgresSize in
            *) break;;
        esac
    done

    echo "Creating ${postgresSize} Postgres service htbhf-claimant-service-postgres"
    echo "cf create-service postgres ${postgresSize} htbhf-claimant-service-postgres"
    cf create-service postgres ${postgresSize} htbhf-claimant-service-postgres
    pause
fi

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
	echo -e "<html>\n<head>\n<title>${WEB_UI_APP_NAME}</title>\n</head>\n<body>\n<p>Temporary holding page</p>\n</body>\n</html>" > index.html
	echo -e "---\napplications:\n- name: ${WEB_UI_APP_NAME}\n  memory: 64M\n  buildpack: staticfile_buildpack" > manifest.yml
	cf push
	cd ..
	rm -rf tmp-holding-page
    pause
else
    echo "${WEB_UI_APP_NAME} already exists (this may be a holding page)"
fi

EXISTING_ROUTE=$(cf routes | grep "${WEB_UI_APP_NAME}-route ")
if [[ -z ${EXISTING_WEB_UI} ]]; then
    echo "Creating route to secure web ui with basic auth"
    # see https://docs.cloud.service.gov.uk/deploying_services/route_services/#example-route-service-to-add-authentication
    mkdir tmp-basic-auth-route
    cd tmp-basic-auth-route
    git clone https://github.com/alext/cf_basic_auth_route_service .
    cf push ${WEB_UI_APP_NAME}-route --no-start
    cf set-env ${WEB_UI_APP_NAME}-route AUTH_USERNAME ${BASIC_AUTH_USER}
    cf set-env ${WEB_UI_APP_NAME}-route AUTH_PASSWORD ${BASIC_AUTH_PASS}
    cf start ${WEB_UI_APP_NAME}-route
    echo "cf create-user-provided-service ${WEB_UI_APP_NAME}-route -r https://${WEB_UI_APP_NAME}-route.${CF_PUBLIC_DOMAIN}"
    cf create-user-provided-service ${WEB_UI_APP_NAME}-route -r https://${WEB_UI_APP_NAME}-route.${CF_PUBLIC_DOMAIN}
    echo "cf bind-route-service ${CF_PUBLIC_DOMAIN} ${WEB_UI_APP_NAME}-route --hostname ${WEB_UI_APP_NAME}"
    cf bind-route-service ${CF_PUBLIC_DOMAIN} ${WEB_UI_APP_NAME}-route --hostname ${WEB_UI_APP_NAME}
    cd ..
    rm -rf tmp-basic-auth-route
    pause
else
    echo "${WEB_UI_APP_NAME}-route already exists"
fi

if cf service logit-ssl-drain >/dev/null 2>/dev/null; then
    echo "logit-ssl-drain already exists"
else
    echo "Setting up logit ssl drain"
    echo "cf create-user-provided-service logit-ssl-drain -l syslog-tls://${LOGIT_ENDPOINT}:${LOGIT_PORT}"
    cf create-user-provided-service logit-ssl-drain -l syslog-tls://${LOGIT_ENDPOINT}:${LOGIT_PORT}
    pause
fi

if cf service variable-service >/dev/null 2>/dev/null; then
    echo "variable-service already exists"
else
    echo "Setting up variable service to provide environment variables to apps"
    echo "cf create-user-provided-service variable-service -p '{\"GA_TRACKING_ID\": \"${GA_TRACKING_ID}\", \"UI_LOG_LEVEL\": \"${UI_LOG_LEVEL}\"}'"
    # for some reason this cf command doesn't run correctly when invoked directly (something about the combination of quote marks, I suspect)
    # but we can write it to a script and source that script instead
    echo "cf create-user-provided-service variable-service -p '{\"GA_TRACKING_ID\": \"${GA_TRACKING_ID}\", \"UI_LOG_LEVEL\": \"${UI_LOG_LEVEL}\"}'" > tmp-variable-service.sh
    source tmp-variable-service.sh
    rm tmp-variable-service.sh
fi

echo "Done"