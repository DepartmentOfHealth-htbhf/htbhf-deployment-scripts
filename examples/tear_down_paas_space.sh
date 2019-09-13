#!/bin/bash

# script to delete all apps and services from a space
# this script is not run as part of any automated process - trigger it manually if required

source ../cf_deployment_functions.sh

 # check necessary environment variables are set and not empty
 # please ensure any changes to required variables are also updated in README.md
check_login_variables_are_set


pause(){
    read -p "Press [Enter] key to continue..."
}


cf_login

echo -e "\nAbout to delete apps in ${CF_SPACE}:"
echo -e "------------------------------------"
cf apps | grep -v "No apps found" | awk 'NR > 3 {print $1}'
echo ""
pause

ALL_APPS=$(cf apps | grep -v "No apps found" | awk 'NR > 3 {print $1}')

for APP in $ALL_APPS; do
  echo "Deleting $APP"
  cf delete $APP -r -f
done

echo -e "\nAbout to delete services in ${CF_SPACE}:"
echo -e "------------------------------------"
cf services | grep -v "delete in progress" | awk 'NR > 3 {print $1}'
echo ""
pause

ALL_SERVICES=$(cf services | grep -v "delete in progress" | awk 'NR > 3 {print $1}')

for SERVICE in $ALL_SERVICES; do
  echo "Deleting $SERVICE"
  cf delete-service $SERVICE -f
done
