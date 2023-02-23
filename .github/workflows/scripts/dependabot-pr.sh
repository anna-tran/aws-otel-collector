#!/bin/zsh -ex

# Copyright The OpenTelemetry Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# NOTICE: This code contains small modifications from the code obtained in: https://github.com/open-telemetry/opentelemetry-go-contrib/blob/main/.github/workflows/scripts/dependabot-pr.sh

# TODO find if we need to create a bot user
git config user.name adotbot
git config user.email adotbot@users.noreply.github.com

PR_NAME=dependabot-prs/`date +'%Y-%m-%dT%H%M%S'`
git checkout -b $PR_NAME

IFS=$'\n'
requests=($( gh pr list --search "author:app/dependabot" --json number,title --jq '.[] | "\(.title) #\(.number)"' ))
message=""
dirs=(`find . -type f -name "go.mod" -exec dirname {} \; | sort | egrep  '^./'`)

declare -A mods

for line in $requests; do
    echo $line
    if [[ $line != Bump* ]]; then
        continue
    fi

    module=$(echo $line | cut -f 2 -d " ")
    if [[ $module == github.com/aws-observability/aws-otel-collector* ]]; then
        continue
    fi

    version=$(echo $line | cut -f 6 -d " ")

    mods[$module]=$version
    message+=$line
    message+=$'\n'
done

for module version in ${(kv)mods}; do
    topdir=`pwd`
    for dir in $dirs; do
        echo "checking $dir"
        cd $dir && if grep -q "$module " go.mod; then go get "$module"@v"$version"; fi
        cd $topdir
    done
done

make go-mod-tidy
make build

git add go.sum go.mod
git add "**/go.sum" "**/go.mod"
git commit -m "dependabot updates `date`
$message"
git push origin $PR_NAME

echo gh pr create --title "dependabot updates `date`" --body "$message" -l "Skip Changelog"
