# Runbook for deployment to and configuration of spaces in GOV.UK PaaS

## Creating a new space
* The new space must be created using the [GOV.UK PaaS dashboard](https://admin.london.cloud.service.gov.uk/organisations/71ede43d-237a-4ce9-8bc0-e2f395a0d8a1).
* Once the space has been created run the [create_services.sh](./create_services.sh) script to set up the required services.
    * You will need the following environment variables set:
    ```
    CF_SPACE - the name of the space to create services for. E.g. 'production'
    CF_API=api.london.cloud.service.gov.uk
    CF_ORG=department-of-health-and-social-care
    CF_USER - your PaaS username/email
    CF_PASS - your PaaS password
    BASIC_AUTH_USER - basic authentication is used to prevent unauthorised visitors from applying
    BASIC_AUTH_PASS
    CF_PUBLIC_DOMAIN=london.cloudapps.digital
    LOGIT_ENDPOINT - see https://docs.cloud.service.gov.uk/monitoring_apps.html#configure-app - this can be obtained from the 'logstash inputs' section of the stack settings in the logit.io dashboard
    LOGIT_PORT - as above, this is the TCP-SSL port
    GA_TRACKING_ID - can be obtained from the google analytics dashboard (https://analytics.google.com -> admin -> Property settings -> Tracking ID for the appropriate property)
    UI_LOG_LEVEL=info (can be silly|debug|info|warn|error)
    DWP_API_URI - the URI to DWP API which can be found from one of the existing services in the space (e.g. eligibility service)
    HMRC_API_URI - the URI to HMRC API which can be found from one of the existing services in the space (e.g. eligibility service)
    NOTIFY_API_KEY - the key to use for Notify API calls f4d5901f-a308-4aa1-a507-cbace83a3bbd
    ```
    * To run this script you must clone this repository then `cd examples; bash ./create_services.sh`.

## Deploying applications to staging and production
There are scripts to trigger the CD pipeline to deploy a specific version of an application to production (via staging).
These scripts are `trigger_cd_to_deploy_[node|java]_app.sh` - see individual scripts for instructions on what environment variables are required.
The scripts will deploy to staging then deploy straight to production (assuming a successful deploy to staging) without running any tests.

There is an additional script to run tests in staging without deploying any applications: `trigger_cd_to_run_tests.sh`

## Updating a variable service
To update a value in a variable service, all values in that service must be provided. 
E.g. `cf update-user-provided-service os-places-variable-service -p '{\"OS_PLACES_API_KEY\": \"${OS_PLACES_API_KEY}\", \"OS_PLACES_URI\": \"${OS_PLACES_URI}\" }'`

Any service that uses that variable service needs to be restaged
E.g. `cf restage apply-for-healthy-start`
