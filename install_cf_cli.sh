#!/bin/bash

echo "Installing cf cli"
if [[ ! -e ${SCRIPT_DIR}/cf ]]; then
    mkdir -p ${SCRIPT_DIR}
    cd ${SCRIPT_DIR}
    wget "https://cli.run.pivotal.io/stable?release=linux64-binary&source=github" -q -O cf.tgz && tar -zxvf cf.tgz && rm cf.tgz
    ./cf --version
    cd ..
fi
