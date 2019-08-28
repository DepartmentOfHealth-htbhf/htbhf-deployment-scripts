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


### Instance counts and sizes
If there exists an instance-sizes properties file for the CloudFoundry space being deployed to 
(e.g. [instance-sizes-staging.properties](instance-sizes-staging.properties))
then the app will be scaled accordingly after deployment (and before smoke tests are performed).
The filename is in the format `instance-sizes-<SPACE>.properties`, while the file itself should have the following format:
```
# app_name=<instance size info>
# where <instance size info> matches the format for instance sizing in the `cf scale` command [square brackets indicate optional data]:
#   [-i INSTANCES] [-k DISK] [-m MEMORY]
# It is important that app_name reflects the name of the app in the manifest (excluding any `((suffix))` ).
# for instance
my-app-name=-i 3 -m 1G
# will scale my-app-name to 3 instances, each with 1GB memory. Do not include the '-f' flag as this will be appended automatically

```
If no such properties file exists for a space, or does not mention the app being deployed, the app will retain the counts and sizes defined in its manifest file.


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

# define the space to deploy to
export CF_SPACE=development

# run the deployment script
/bin/bash ${SCRIPT_DIR}/deploy.sh
```
Then invoke this script in your travis-ci build - in `.circleci/config.yml`:
```
script:
- ./gradlew build -s && ./ci_scripts/ci_deploy.sh && ./gradlew ciPerformRelease -s
```
(This example assumes your project uses gradle with the shipkit plugin).

### Chrome version and chromedriver mismatch problems

In order for the browser based tests to function correctly, it is vital that the version of Chrome we use is supported by the version
of [chromedriver](https://www.npmjs.com/package/chromedriver) we use. As we always use the latest version of Chrome in Travis, and 
have no control over this, the tests will fail when the npm package isn't updated to support this new version. We have seen this in
the [following build](https://travis-ci.com/DepartmentOfHealth-htbhf/htbhf-continous-delivery/builds/109416943), which gave the following
error where the latest stable version of chrome became version 74:

```
Error: SessionNotCreatedError: session not created: Chrome version must be between 70 and 73
         (Driver info: chromedriver=73.0.3683.20 (8e2b610813e167eee3619ac4ce6e42e3ec622017),platform=Linux 4.4.0-101-generic x86_64)
           at EnterName.open (/home/travis/build/DepartmentOfHealth-htbhf/htbhf-continous-delivery/application/htbhf-applicant-web-ui-0.1.175/src/test/common/page/page.js:35:13)
           at <anonymous>
           at process._tickCallback (internal/process/next_tick.js:188:7)
```

When this does happen, until there is a new version of chromedriver, it is possible to download and use a different version
of chromedriver as a part of the build process for both web-ui and continuous-delivery. This has been done
for version 74 of chrome and chromedriver and can be seen in the following commits:

- [htbhf-applicant-web-ui](https://github.com/DepartmentOfHealth-htbhf/htbhf-applicant-web-ui/pull/221/files)
- [htbhf-continous-delivery](https://github.com/DepartmentOfHealth-htbhf/htbhf-continous-delivery/pull/68/files)

Ideally, when a new version of chromedriver is released to support the new version os Chrome, this should be reverted and the new
version used instead - this note should be retained in the readme as a useful reference should this happen again.
