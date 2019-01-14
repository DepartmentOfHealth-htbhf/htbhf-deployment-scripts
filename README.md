# htbhf-deployment-scripts

Common scripts required to deploy projects to cloudfoundry using a blue/green deployment pattern,
and running user-defined smoke tests to verify the new service is running.

### Variables used when deploying the app
When invoking the `cf push` command, a number of variables are provided that can be referred to in the `manifest.yml` file:

- `app-suffix` - e.g. `-development-green`, a suffix to be appended to the application name, to distinguish the new (green) version from the existing version.
- `space-suffix` - e.g. `-development`, a suffix to distinguish apps between environments.
- `session_secret` - e.g. `veryverysecret`, may be used to define any secrets required by the app (e.g. the session secret required by redis).

These may be used in the CloudFoundry `manifest.yml` file as follows, for example:
```.yaml
applications:
- name: my-app((app-suffix))
  env:
    SESSION_SECRET: '((session_secret))'
    DOWNSTREAM_SERVICE_URL: http://other-service((space-suffix)).apps.internal:8080
```

### Network Policies
In order to allow communications between apps in CloudFoundry we must explicitly invoke `cf add-network-policy` to open a channel between each pair of apps that need to communicate.
This is handled by the deployment scripts, for each pair of applications listed in `network-policies.properties` (in this project).
Refer to the comments in `network-policies.properties` for more information on the format.

### Environment variables
These scripts require the following environment variables to be set:

- `BIN_DIR ` - the directory where these scripts (and the cf cli tool) will be downloaded. E.g. ./bin.
- `APP_NAME ` - the name of the application
- `APP_NAME ` - the name of the application
- `APP_VERSION ` - the version to be deployed.
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

# download the deployment script(s)

mkdir -p ${BIN_DIR}
rm -rf ${BIN_DIR}/deployment-scripts
mkdir ${BIN_DIR}/deployment-scripts

curl -H "Authorization: token ${GH_WRITE_TOKEN}" -s https://api.github.com/repos/DepartmentOfHealth-htbhf/htbhf-deployment-scripts/releases/latest \
| grep zipball_url \
| cut -d'"' -f4 \
| wget -qO deployment-scripts.zip -i -

unzip deployment-scripts.zip
mv -f DepartmentOfHealth-htbhf-htbhf-deployment-scripts-*/* ${BIN_DIR}/deployment-scripts
rm -rf DepartmentOfHealth-htbhf-htbhf-deployment-scripts-*
rm deployment-scripts.zip

export SCRIPT_DIR=${BIN_DIR}/deployment-scripts

# determine APP_PATH
APP_VERSION=`cat version.properties | grep "version" | cut -d'=' -f2`
APP_PATH="build/libs/$APP_NAME-$APP_VERSION.jar"
# note that for node projects APP_PATH would simply be `.`


# run the deployment script
/bin/bash ${SCRIPT_DIR}/deploy.sh
```
Then invoke this script in your travis-ci build - in `.travis.yml`:
```
script:
- ./gradlew build -s && ./ci_scripts/ci_deploy.sh && ./gradlew ciPerformRelease -s
```
(This example assumes your project uses gradle with the shipkit plugin).
