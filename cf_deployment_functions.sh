#!/bin/bash

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

  cf push -p ${APP_PATH} --var suffix=${SPACE_SUFFIX} --var session_secret="secret_${SESSION_SECRET}"
  add_network_polices ${SPACE_SUFFIX}

  ROUTE=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 16 | head -n 1)
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

  set_app_version_environment_variable
}

perform_blue_green_deployment() {
  echo "$APP_FULL_NAME exists, performing blue-green deployment"
  BLUE_APP="${APP_FULL_NAME}"
  GREEN_APP="${APP_FULL_NAME}-green"

  echo "# pushing new (green) app without a route"
  cf push -p ${APP_PATH} --var app-suffix=${SPACE_SUFFIX}-green --var space-suffix=${SPACE_SUFFIX} --var session_secret="secret_${SESSION_SECRET}" --no-route
  add_network_polices ${SPACE_SUFFIX}-green

  echo "# creating a temporary (public) route to the green app"
  ROUTE=$(cat /dev/urandom | tr -dc 'a-z' | fold -w 16 | head -n 1)
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

  set_app_version_environment_variable
}

unmap_blue_route() {
  if cf check-route ${APP_FULL_NAME} ${CF_DOMAIN}; then
    cf unmap-route ${APP_FULL_NAME} ${CF_DOMAIN} --hostname ${APP_FULL_NAME}
  fi
}

set_app_version_environment_variable() {
  echo "# setting APP_VERSION=${APP_VERSION} for ${APP_FULL_NAME}"
  cf set-env ${APP_FULL_NAME} APP_VERSION "${APP_VERSION}"
}

add_network_polices() {
  suffix=$1
  cat ${SCRIPT_DIR}/network-policies.properties | grep ${APP_NAME} | while read route
  do
    # src and dest must have <<suffix>> replaced according to whether they are the application currently being deployed
    src=$(echo ${route} | cut -d= -f1)
    if [ ${src} = "${APP_NAME}<<suffix>>" ]; then
      src=$(echo ${src} | sed "s/<<suffix>>/$suffix/g")
    else
      src=$(echo ${src} | sed "s/<<suffix>>/${SPACE_SUFFIX}/g")
    fi

    dest=$(echo ${route} | cut -d= -f2)
    if [ ${dest} = "${APP_NAME}<<suffix>>" ]; then
      dest=$(echo ${dest} | sed "s/<<suffix>>/$suffix/g")
    else
      dest=$(echo ${dest} | sed "s/<<suffix>>/${SPACE_SUFFIX}/g")
    fi

    echo "creating network policy from $src to $dest"
    cf add-network-policy ${src} --destination-app ${dest} --protocol tcp --port 8080
  done

  echo "Finished creating network polices"
}
