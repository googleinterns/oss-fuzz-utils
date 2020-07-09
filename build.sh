#!/bin/bash
#
# Build a local OSS-Fuzz project. Please ensure that oss-fuzz-utils
# and oss-fuzz are sibling directories, and run build.sh from within
# the oss-fuzz-utils directory.

function usage {
  echo "Usage: sh build.sh <project>"
  exit 1
}

pushd ../oss-fuzz
project_name=$1
[[ -z "$project_name" ]] && usage
sudo rm -rf ./build/work/${project_name}
sudo rm -rf ./build/out/${project_name}
clear
yes | sudo python3 infra/helper.py build_image $project_name
sudo python3 infra/helper.py build_fuzzers $project_name
popd
