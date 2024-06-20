#!/bin/bash

# Ensure the script exits if any command fails
set -e

# Get the absolute path of the script
SCRIPT_PATH=$(realpath "$0")

# Get the directory of the script
SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
TEMPLATE_DIR=$(dirname $(dirname "$SCRIPT_DIR"))/templates
# AMI name pattern or specific AMI ID to search for
AMI_NAME_PATTERN="Deep Learning Base OSS Nvidia Driver GPU AMI (Ubuntu 22.04) 20240610"

# File to update with new AMI mappings
TEMPLATE_FILE="$TEMPLATE_DIR/autoRAG.yml"

# Function to get AMI ID for a region
get_ami_id() {
  local region=$1
  aws ec2 describe-images --region "$region" --filters "Name=name,Values=$AMI_NAME_PATTERN" "Name=architecture,Values=x86_64" --query "Images[0].ImageId" --output text
}

# Get the list of all AWS regions
REGIONS=$(aws ec2 describe-regions --query "Regions[*].RegionName" --output text)

# Initialize the mappings section
AMI_MAPPINGS="  RegionMap:\n"

# Iterate through each region and get the AMI ID
for REGION in $REGIONS; do
  AMI_ID=$(get_ami_id "$REGION")
  if [ "$AMI_ID" != "None" ]; then
    AMI_MAPPINGS+="    $REGION:\n      AMIID: $AMI_ID\n"
  else
    AMI_MAPPINGS+="    $REGION:\n      AMIID: 'AMI not found'\n"
  fi
done

# Read the current template file and update only the RegionMap within Mappings section
awk -v new_mappings="$AMI_MAPPINGS" '
  BEGIN {in_mappings = 0}
  /^Mappings:/ {print; in_mappings = 1; next}
  /^Resources:/ {in_mappings = 0}
  !in_mappings {print}
  in_mappings {
    if (/^  RegionMap:/) {
      print new_mappings
      while (getline && $0 !~ /^  [^ ]/) {}
      print
    } else {
      print
    }
  }
' "$TEMPLATE_FILE" > "$TEMPLATE_FILE.tmp" && mv "$TEMPLATE_FILE.tmp" "$TEMPLATE_FILE"
echo "Updated CloudFormation template with new AMI IDs."
