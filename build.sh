#!/bin/bash
#
# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Build a local OSS-Fuzz project. Please ensure that oss-fuzz-utils
# and oss-fuzz are sibling directories, and run build.sh from within
# the oss-fuzz-utils directory.

function usage {
  echo "Usage: sh build.sh <project>"
  exit 1
}

null_out="/dev/null"
pushd ../oss-fuzz > $null_out
project_name=$1
[[ -z "$project_name" ]] && usage
sudo rm -rf ./build/work/${project_name}
sudo rm -rf ./build/out/${project_name}
clear
yes | sudo python3 infra/helper.py build_image $project_name
sudo python3 infra/helper.py build_fuzzers $project_name
popd > $null_out
