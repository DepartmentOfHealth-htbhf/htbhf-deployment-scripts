# htbhf-deployment-scripts

Common scripts required to deploy projects to cloudfoundry using a blue/green deployment pattern,
and running user-defined smoke tests to verify the new service is running.

These scripts require the following environment variables to be set:

- `BIN_DIR ` - the directory where these scripts (and the cf cli tool) will be downloaded. E.g. ./bin.
- `APP_NAME ` - the name of the application
- `APP_PATH ` - the location of the application on the local filesystem.
For Java apps, it must be pointed to a valid jar or war file - e.g. `build/libs/my-app-1.0.0.jar`.
For Non-Java apps, it must be pointed to the app root directory - e.g. `.`.
- `CF_API` - the api to use when logging into cf
- `CF_ORG` - the org to use when logging into cf
- `CF_USER` - the user to use when logging into cf
- `CF_PASS` - the password to use when logging into cf
- `CF_SPACE` - the space to use when logging into cf
- `CF_DOMAIN` - the domain the application will be visible in. E.g. apps.internal for private apps.
- `CF_PUBLIC_DOMAIN` - a domain, visible to the outside world, to which a (randomly named) route will be created to allow smoke testing. 
- `SMOKE_TESTS` - the script to invoke smoke tests. 
Will be passed a single parameter - the hostname of the public route to run tests against.


Suggested usage is to add a ci_deploy script to your project (e.g. as `ci_scripts/ci_deploy.sh`): - this example is for a java project
```
#!/bin/bash

# if this is a pull request or branch (non-master) build, then just exit
echo "TRAVIS_PULL_REQUEST=$TRAVIS_PULL_REQUEST, TRAVIS_BRANCH=$TRAVIS_BRANCH"
if [[ "$TRAVIS_PULL_REQUEST" != "false"  || "$TRAVIS_BRANCH" != "master" ]]; then
   echo "Not deploying pull request or branch build"
   exit
fi

# ensure the variables required by this script are set
check_variable_is_set(){
    if [[ -z ${!1} ]]; then
        echo "$1 must be set and non empty"
        exit 1
    fi
}

check_variable_is_set BIN_DIR
check_variable_is_set DEPLOY_SCRIPTS_URL
check_variable_is_set DEPLOY_SCRIPT_VERSION

# download the deployment script(s)
if [[ ! -e ${BIN_DIR}/deploy_scripts_${DEPLOY_SCRIPT_VERSION} ]]; then
    echo "Installing deploy scripts version ${DEPLOY_SCRIPT_VERSION}"
    mkdir -p ${BIN_DIR}
    cd ${BIN_DIR}
    wget "${DEPLOY_SCRIPTS_URL}/${DEPLOY_SCRIPT_VERSION}.zip" -q -O deploy_scripts.zip && unzip -j -o deploy_scripts.zip && rm deploy_scripts.zip
    touch deploy_scripts_${DEPLOY_SCRIPT_VERSION}
    cd ..
fi

# determine APP_PATH
APP_VERSION=`cat version.properties | grep "version" | cut -d'=' -f2`
APP_PATH="build/libs/$APP_NAME-$APP_VERSION.jar"
# note that for node projects APP_PATH would simply be `.`


# run the deployment script
/bin/bash ${BIN_DIR}/deploy.sh
```
The invoke this script in your travis-ci build - in `.travis.yml`:
```
script:
- ./gradlew build -s && ./ci_scripts/ci_deploy.sh && ./gradlew ciPerformRelease -s
```
(This example assumes your project uses gradle with the shipkit plugin).