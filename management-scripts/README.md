# Deploying and managing applications

## Deploying applications to staging and production
There are scripts to trigger the CD pipeline to deploy a specific version of an application to production (via staging).
These scripts are `trigger_cd_to_deploy_[node|java]_app.sh` - see individual scripts for instructions on what environment variables are required.
The scripts will deploy to staging then deploy straight to production (assuming a successful deploy to staging) without running any tests.

There is an additional script to run tests in staging without deploying any applications: `trigger_cd_to_run_tests.sh`

## Displaying a 'service unavailable page'
The frontend can be taken down for planned maintenance and have a holding page shown instead. To do this, go into the 
management scripts directory (`cd  management-scripts`) and run `./turn-on-holding-page.sh [service available date]`, 
e.g. `./turn-on-holding-page.sh "14:45 05/06/2019"` 

If no date is given then the holding page will display 'Try again later'

To disable the holding page and have the application running again, run `./turn-off-holding-page.sh`
