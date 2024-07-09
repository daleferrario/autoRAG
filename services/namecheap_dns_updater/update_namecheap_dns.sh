#!/bin/sh

# Configuration
HOSTNAME_WILDCARD="sub"  # The subdomain you want to update, e.g., *.example.com
HOSTNAME_BASE=""  # The base domain

# Ensure DOMAIN_NAME and DDNS_API_KEY are set
if [ -z "$DOMAIN_NAME" ] || [ -z "$DDNS_API_KEY" ]; then
  echo "[$(date)] DOMAIN_NAME or DDNS_API_KEY environment variables are not set."
  exit 1
fi

# Get the current public IP address
CURRENT_IP=$(curl -s ifconfig.me)
if [ -z "$CURRENT_IP" ]; then
  echo "[$(date)] Failed to retrieve current IP address."
  exit 1
fi
echo "[$(date)] Current IP address: ${CURRENT_IP}"

# Function to update DNS record
update_dns_record() {
  local host=$1
  RESPONSE=$(curl -s "https://dynamicdns.park-your-domain.com/update?host=${host}&domain=${DOMAIN_NAME}&password=${DDNS_API_KEY}&ip=${CURRENT_IP}")
  echo "[$(date)] DNS update response for ${host}${DOMAIN_NAME}: $RESPONSE"
}

# Function to check if the current IP matches the DNS record
check_dns_record() {
  local host=$1
  DNS_IP=$(dig +short ${host}${DOMAIN_NAME})
  if [ -z $host ]; then
    host="@"
  fi
  if [ "$CURRENT_IP" = "$DNS_IP" ]; then
    echo "[$(date)] IP address for ${host}${DOMAIN_NAME} has not changed. Current IP: $CURRENT_IP"
  else
    echo "[$(date)] IP address for ${host}${DOMAIN_NAME} has changed. Updating DNS record."
    update_dns_record $host
  fi
}

# Check DNS records and update if necessary
check_dns_record "$HOSTNAME_WILDCARD."
check_dns_record $HOSTNAME_BASE
