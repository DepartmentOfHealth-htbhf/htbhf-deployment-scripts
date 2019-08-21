#!/bin/bash

# This script is intended to create a tagged release of the deployment scripts themselves
# - it is not intended for use in other projects.
# It will simply increment the patch version on every PR to master.
# To update the major/minor versions, manually create a release on GitHub.

# quit at the first error
set -e

git config --local user.email "dhsc-htbhf-support@equalexperts.com"
git config --local user.name "ci-build"

# make sure we know about all tags
git fetch --tags -q

# Get the latest git tag (e.g. 1.2.43)
GIT_LATEST_TAG=$(git describe --tags $(git rev-list --tags --max-count=1))
# Split out the major and minor version and the patch version into separate parts (e.g. 1.2. 43):
LAST_VERSION=$(echo "$GIT_LATEST_TAG" | sed -E 's/^([0-9]{1,}\.[0-9]{1,}\.)([0-9]{1,})$/\1 \2/g';)
# Increment the patch
NEW_VERSION=$(echo "$LAST_VERSION" | awk '{printf($1$2+1)}')
echo "GIT_LATEST_TAG=$GIT_LATEST_TAG, NEW_VERSION=$NEW_VERSION"

# tag the new release in git
git tag -a ${NEW_VERSION} -m "Release $NEW_VERSION"

# push the new tag back to github
GITHUB_REPO_SLUG=${CIRCLE_PROJECT_USERNAME}/${CIRCLE_PROJECT_REPONAME}

echo "git push https://[SECRET]@github.com/${GITHUB_REPO_SLUG}.git ${NEW_VERSION}"
git push https://${GH_WRITE_TOKEN}@github.com/${GITHUB_REPO_SLUG}.git ${NEW_VERSION}

# create the release in github
body="{\"tag_name\": \"${NEW_VERSION}\", \"name\": \"${NEW_VERSION}\"}"
curl -H "Authorization: token ${GH_WRITE_TOKEN}" -H "Content-Type: application/json" -d "${body}" https://api.github.com/repos/${GITHUB_REPO_SLUG}/releases
