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
    ```
    * To run this script you must clone this repository then `cd examples; bash ./create_services.sh`.