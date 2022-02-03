#!/usr/bin/env bash

# Copyright 2022 XLTS.dev. All rights reserved. https://xlts.dev
# Licensed under the MIT License.
#
# This script expects the authentication token to be passed as the first and only argument when being invoked. This
# script has been tested to work in the following environments:
#  * Linux
#  * macOS
#  * Windows - WSL, GitBash, Cygwin
#
# This script will perform the following actions when executed:
#  1. Download all XLTS for AngularJS package tarballs to a 'tarballs' directory at the same location where this script resides.
#  2. Extract the XLTS for AngularJS package tarballs to a 'packages' directory at the same location where this script resides.
#
# Example usage of this script:
# `./angular/download.sh FULL_AUTH_TOKEN_STRING`

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# The full JWT token should be passed as the first and only argument to this script
TOKEN="$1"
REGISTRY="https://registry.xlts.dev"
ANGULAR_PACKAGES=(
  'angular'
  'angular-animate'
  'angular-aria'
  'angular-cookies'
  'angular-i18n'
  'angular-message-format'
  'angular-messages'
  'angular-mocks'
  'angular-parse-ext'
  'angular-resource'
  'angular-route'
  'angular-sanitize'
  'angular-touch'
)

function insert_header() {
  echo -e "\n$1\n--------------------"
}

# If the JWT token was not passed in as the first argument, fail and exit
if [[ -z "${TOKEN}" ]]; then
  echo "ERROR: The authentication token must be passed as the first argument to the script" 1>&2
  exit 1
fi

# Decode the JWT token payload
# https://unix.stackexchange.com/questions/631501/base64-d-decodes-but-says-invalid-input/631503#631503
TOKEN_DECODED="$(echo "$(echo "${TOKEN}" | cut -d'.' -f2)====" | fold -w 4 | sed '$ d' | tr -d '\n' | base64 --decode)"
if [[ "${TOKEN_DECODED}" != \{* || "${TOKEN_DECODED}" != *\} ]]; then
  echo "ERROR: Unable to decode the authentication token" 1>&2
  exit 1
fi

# Extract the username from the decoded JWT token payload
TOKEN_USER="$(echo "${TOKEN_DECODED}" | awk -F'"name":' '{print $2}' | cut -d',' -f1 | tr -d '"')"
if [[ -z "${TOKEN_USER}" ]]; then
  echo "ERROR: Unable to extract the username from the authentication token" 1>&2
  exit 1
fi

# Determine the latest published version of the XLTS for AngularJS packages
ANGULAR_VERSION="$(curl -f --silent "${REGISTRY}/@xlts.dev/${ANGULAR_PACKAGES[0]}" -H "Authorization: Bearer ${TOKEN}" | awk -F'"latest":' '{print $2}' | xargs)"
if [[ -z "${ANGULAR_VERSION}" ]]; then
  echo "ERROR: Unable to determine the latest XLTS for AngularJS version" 1>&2
  exit 1
fi

# Exit when any command fails
set -e
# Keep track of the last executed command
trap 'last_command=$current_command; current_command=$BASH_COMMAND' DEBUG
# Echo an error message before exiting if a command fails
trap '[ $? != 0 ] && echo -e "The following command failed:\n ▶ ${last_command}"' EXIT

echo "Registry: ${REGISTRY}"
echo "Username: ${TOKEN_USER}"
echo "Total packages: ${#ANGULAR_PACKAGES[@]}"
echo "XLTS for AngularJS version: ${ANGULAR_VERSION}"
echo
read -r -p "Do you wish to download the XLTS for AngularJS packages (y/n)? " response
case $response in
  [yY]*) echo;;
  *) echo; echo "Download aborted"; exit;;
esac

# Remove the existing output directories if they exist
rm -rf "${SCRIPT_DIR}/tarballs" "${SCRIPT_DIR}/packages"

# Create the output directories
mkdir -p "${SCRIPT_DIR}/tarballs" "${SCRIPT_DIR}/packages"

insert_header "Downloading"

# Download the XLTS for AngularJS package tarballs
for package in "${ANGULAR_PACKAGES[@]}"; do
  tarball="${package}-${ANGULAR_VERSION}.tgz"
  output="${SCRIPT_DIR}/tarballs/${tarball}"
  echo "Downloading ${package} to '${output}'"
  curl -f -# "${REGISTRY}/@xlts.dev/${package}/-/${tarball}" -H "Authorization: Bearer ${TOKEN}" > "${output}"
  echo
done

insert_header "Extracting"

# Extract the XLTS for AngularJS package tarballs
for tarball in "${SCRIPT_DIR}"/tarballs/*.tgz; do
  # Git Bash on Windows does not have the `rev` command
  # macOS does not have the `tac` command
  if ! command -v rev &> /dev/null; then
    # The code `fold -w1 | tac | tr -d '\n'` is equivalent to using `rev`
   package_name="$(basename "${tarball}" | fold -w1 | tac | tr -d '\n' | cut -d"-" -f2- | fold -w1 | tac | tr -d '\n')"
  else
    package_name="$(basename "${tarball}" | rev | cut -d"-" -f2- | rev)"
  fi

  output="${SCRIPT_DIR}/packages/${package_name}"
  mkdir -p "${output}"
  echo "Extracting '${package_name}' to '${output}'"
  tar -xf "${tarball}" --strip-components=1 -C "${output}"
done

insert_header "Successfully downloaded and extracted ${#ANGULAR_PACKAGES[@]} XLTS for AngularJS packages:"
find "${SCRIPT_DIR}/packages" -maxdepth 1 -type d | tail -n +2
