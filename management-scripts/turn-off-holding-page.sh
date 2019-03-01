#!/bin/bash

source ../cf_deployment_functions.sh

check_login_variables_are_set

cf_login

SPACE_SUFFIX="-${CF_SPACE}"
if [[ ${CF_SPACE} == 'production' ]]; then
	SPACE_SUFFIX=''
fi
export SPACE_SUFFIX

ENV_VARIABLES=`cf env help-to-buy-healthy-foods${SPACE_SUFFIX}`
GA_TRACKING_ID=`echo "${ENV_VARIABLES}" | grep GA_TRACKING_ID | cut -d':' -f2 | cut -d',' -f1`
UI_LOG_LEVEL=`echo "${ENV_VARIABLES}" | grep UI_LOG_LEVEL | cut -d':' -f2 | cut -d',' -f1`

cf update-user-provided-service variable-service -p "'{ \"GA_TRACKING_ID\":${GA_TRACKING_ID}, \"UI_LOG_LEVEL\": ${UI_LOG_LEVEL} }'"

echo
echo "Restarting starting the application. There will be downtime for a few seconds"
echo
cf restart help-to-buy-healthy-foods${SPACE_SUFFIX}
