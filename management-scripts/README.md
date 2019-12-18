# Deploying and managing applications

## Deploying applications to staging and production
There are scripts to trigger the CD pipeline to deploy a specific version of an application to production (via staging).
These scripts are `trigger_circleci_cd_to_deploy_[node|java]_app.sh` - see individual scripts for instructions on what environment variables are required.
The scripts will deploy to staging then deploy straight to production (assuming a successful deploy to staging) without running any tests.

#### To deploy a java app
You will need to set the following environment variables (`export VAR_NAME="var value"`):
```
APP_NAME - The name of the application to deploy. E.g. 'htbhf-claimant-service'
APP_VERSION - The version to deploy. Should match the version number in Bintray, and exclude any leading 'v'.
TRAVIS_AUTH_TOKEN - The Travis-ci token. Available from travis-ci.com in my account -> settings.
```
Then run `./trigger_circleci_cd_to_deploy_java_app.sh`

#### To deploy a node app
You will need to set the following environment variables (`export VAR_NAME="var value"`):
```
APP_NAME - The name of the application as deployed. E.g. 'apply-for-healthy-start'
APP_VERSION - The version to deploy. Should match the version in Github, but exclude the leading 'v'.
REPO_NAME - The name of the project in github. E.g. 'htbhf-applicant-web-ui'
TRAVIS_AUTH_TOKEN - The Travis-ci token. Available from travis-ci.com in my account -> settings.
```
Then run `./trigger_circleci_cd_to_deploy_node_app.sh`

----
There is an additional script to run tests in staging without deploying any applications: `trigger_circleci_cd_to_run_tests.sh`

## Displaying a 'service unavailable page'
The frontend can be taken down for planned maintenance and have a holding page shown instead. To do this, go into the 
management scripts directory (`cd  management-scripts`) and run `./turn-on-holding-page.sh [service available date]`, 
e.g. `./turn-on-holding-page.sh "14:45 05/06/2019"` 

If no date is given then the holding page will display 'Try again later'

To disable the holding page and have the application running again, run `./turn-off-holding-page.sh`.

You will need to have the following environment variables set:
```
CF_SPACE - The name of the space to set up services for
CF_API - E.g. api.london.cloud.service.gov.uk
CF_ORG - E.g. department-of-health-and-social-care
CF_USER - Your cloudfoundry username/email address
CF_PASS - Your cloudfoundry password
```
