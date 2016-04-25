#!/bin/bash

# This shell script is designed to allow easy submission of CLs
# to Google's V8 repository.
# To use this script, simply run it when all code to be submitted
# has been committed to local repository.
# This script must be placed in the v8 directory.

# NOTE, you must have a different branch for each CL.

tools/presubmit.py
if [ "$?" != 0 ]; then
  echo "Presubmit errors detected. Please correct before continuing."
  exit 1
fi
git cl format
git add --u
git commit -m "Ran git cl format"
git cl upload
