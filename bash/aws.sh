#!/bin/sh

# Check if AWS Access Key, Secret Key, and Region are passed as arguments
if [ "$#" -ne 3 ]; then
  echo "Usage: $0 <AWS_ACCESS_KEY_ID> <AWS_SECRET_ACCESS_KEY> <AWS_REGION>"
  exit 1
fi

# Set the AWS Access Key ID, Secret Access Key, and Region from arguments
AWS_ACCESS_KEY_ID="$1"
AWS_SECRET_ACCESS_KEY="$2"
AWS_REGION="$3"

# Export the AWS environment variables
export AWS_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY
export AWS_REGION


# Simulate user input for aws configure
echo -e "$AWS_ACCESS_KEY_ID\n$AWS_SECRET_ACCESS_KEY\n$AWS_REGION\njson" | aws configure

# Optionally, confirm the configuration by running an AWS CLI command
aws s3 ls
