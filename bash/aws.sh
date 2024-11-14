#!/bin/sh

# Loop through and export environment variables passed
echo "Exporting environment variables:"
for env_var in "$@"; do
  export $env_var
  echo "Exported: $env_var"
done

# Optionally, print all environment variables after export
echo "All environment variables:"
env
