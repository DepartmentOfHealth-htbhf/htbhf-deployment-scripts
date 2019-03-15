#!/bin/bash

export TMP_VARS_FILE="tmp-vars.yml"

check_login_variables_are_set() {
  check_variable_is_set CF_SPACE "The name of the space to set up services for"
  check_variable_is_set CF_API "E.g. api.london.cloud.service.gov.uk"
  check_variable_is_set CF_ORG "E.g. department-of-health-and-social-care)"
  check_variable_is_set CF_USER "Your cloudfoundry username/email address"
  check_variable_is_set CF_PASS "Your cloudfoundry password"
}

check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty. ($2)"
        exit 1
    fi
}

cf_login() {
  echo "Logging into cloud foundry with api:$CF_API, org:$CF_ORG, space:$CF_SPACE, user:$CF_USER"
  cf login -a ${CF_API} -u ${CF_USER} -p "${CF_PASS}" -s ${CF_SPACE} -o ${CF_ORG}
}

create_random_route_name() {
  export ROUTE=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 16 | head -n 1)
}

remove_route() {
  MY_HOST=$1
  MY_DOMAIN=$2
  MY_APP=$3
  if cf check-route ${MY_HOST} ${MY_DOMAIN} | grep "does exist"; then
    cf unmap-route $3 ${MY_DOMAIN} --hostname ${MY_HOST}
    cf delete-route -f ${MY_DOMAIN} --hostname ${MY_HOST}
  fi
}

perform_first_time_deployment() {
  echo "$APP_FULL_NAME does not exist, doing regular deployment"

  write_tmp_vars_file ${SPACE_SUFFIX}
  echo "cf push -p ${APP_PATH} --vars-file ${TMP_VARS_FILE}"
  cf push -p ${APP_PATH} --vars-file ${TMP_VARS_FILE}
  RESULT=$?
  rm ${TMP_VARS_FILE}
  if [[ ${RESULT} != 0 ]]; then
    cf logs ${APP_FULL_NAME} --recent
    echo "cf push failed - exiting now"
    exit 1
  fi
  scale_instances ${SPACE_SUFFIX}
  add_network_polices ${SPACE_SUFFIX}

  create_random_route_name
  cf map-route ${APP_FULL_NAME} ${CF_PUBLIC_DOMAIN} --hostname ${ROUTE}

  echo "# run smoke tests"
  (${SMOKE_TESTS} ${ROUTE}.${CF_PUBLIC_DOMAIN})
  RESULT=$?

  remove_route ${ROUTE} ${CF_PUBLIC_DOMAIN} ${APP_FULL_NAME}

  if [[ ${RESULT} != 0 ]]; then
    echo "# Smoke tests failed, reading logs from $APP_FULL_NAME"
    cf logs ${APP_FULL_NAME} --recent
    echo "# Rolling back deployment of $APP_FULL_NAME"
    cf delete -f -r ${APP_FULL_NAME}
    exit 1
  fi

}

perform_blue_green_deployment() {
  echo "$APP_FULL_NAME exists, performing blue-green deployment"
  BLUE_APP="${APP_FULL_NAME}"
  GREEN_APP="${APP_FULL_NAME}-green"

  echo "# pushing new (green) app without a route"
  write_tmp_vars_file ${SPACE_SUFFIX}-green
  echo "cf push -p ${APP_PATH} --vars-file ${TMP_VARS_FILE} --no-route"
  cf push -p ${APP_PATH} --vars-file ${TMP_VARS_FILE} --no-route
  RESULT=$?
  rm ${TMP_VARS_FILE}
  if [[ ${RESULT} != 0 ]]; then
    cf logs ${GREEN_APP} --recent
    echo "cf push failed - exiting now"
    exit 1
  fi
  scale_instances ${SPACE_SUFFIX}-green
  add_network_polices ${SPACE_SUFFIX}-green

  echo "# creating a temporary (public) route to the green app"
  create_random_route_name
  cf map-route ${GREEN_APP} ${CF_PUBLIC_DOMAIN} --hostname ${ROUTE}

  echo "# run smoke tests"
  (${SMOKE_TESTS} ${ROUTE}.${CF_PUBLIC_DOMAIN})
  RESULT=$?

  echo "# removing the temporary route"
  remove_route ${ROUTE} ${CF_PUBLIC_DOMAIN} ${GREEN_APP}

  # roll back if tests failed
  if [[ ${RESULT} != 0 ]]; then
    echo "# Smoke tests failed, reading logs from $GREEN_APP"
    cf logs ${GREEN_APP} --recent
    echo "# Rolling back deployment of $GREEN_APP"
    cf delete -f -r ${GREEN_APP}
    exit 1
  fi

  echo "# start routing traffic to green (in addition to blue)"
  cf map-route ${GREEN_APP} ${CF_DOMAIN} --hostname ${APP_FULL_NAME}
  echo "# stop routing traffic to blue"
  unmap_blue_route
  echo "# delete blue"
  cf delete -f ${BLUE_APP}
  echo "# rename green -> blue"
  cf rename ${GREEN_APP} ${BLUE_APP}
}

write_tmp_vars_file() {
  app_suffix=${1:-'""'}
  app_version=${APP_VERSION:-'""'}
  space_suffix=${SPACE_SUFFIX:-'""'}
  echo "---" > ${TMP_VARS_FILE}
  echo "app-suffix: ${app_suffix}" >> ${TMP_VARS_FILE}
  echo "app-version: ${app_version}" >> ${TMP_VARS_FILE}
  echo "space-suffix: ${space_suffix}" >> ${TMP_VARS_FILE}
  echo "session_secret: secret_${SESSION_SECRET}" >> ${TMP_VARS_FILE}
}

unmap_blue_route() {
  if cf check-route ${APP_FULL_NAME} ${CF_DOMAIN}; then
    cf unmap-route ${APP_FULL_NAME} ${CF_DOMAIN} --hostname ${APP_FULL_NAME}
  fi
}

scale_instances() {
  suffix=$1
  appname="${APP_NAME}${suffix}"
  filename="${SCRIPT_DIR}/instance-sizes-${CF_SPACE}.properties"
  if [ -f "${filename}" ]; then
    cat ${filename} | grep ${APP_NAME} | while read instances
    do
      sizing=$(echo ${instances} | cut -d= -f2)

      echo "cf scale ${appname} ${sizing} -f"
      cf scale ${appname} ${sizing} -f
      RESULT=$?
      if [[ ${RESULT} != 0 ]]; then
        echo "cf scale failed - exiting now"
        exit 1
      fi

    done

  else
    echo "${filename} does not exist - not scaling the app (will have the instance count/size defined in the manifest.yml file)"
  fi

}

add_network_polices() {
  suffix=$1
  cat ${SCRIPT_DIR}/network-policies.properties | grep ${APP_NAME} | while read route
  do
    # src and dest must have a suffix appended according to whether they are the application currently being deployed
    # i.e. 'app-name${suffix}' for the app being deployed, 'app-name${SPACE_SUFFIX}' for other apps
    src=$(echo ${route} | cut -d= -f1)
    if [ ${src} = "${APP_NAME}" ]; then
      src="${src}${suffix}"
    else
      src="${src}${SPACE_SUFFIX}"
    fi

    dest=$(echo ${route} | cut -d= -f2)
    if [ ${dest} = "${APP_NAME}" ]; then
      dest="${dest}${suffix}"
    else
      dest="${dest}${SPACE_SUFFIX}"
    fi

    echo "creating network policy from $src to $dest"
    cf add-network-policy ${src} --destination-app ${dest} --protocol tcp --port 8080
  done

  echo "Finished creating network policies"
}
