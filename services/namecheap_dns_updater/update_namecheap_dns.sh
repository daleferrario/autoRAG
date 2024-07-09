#!/bin/sh

# Configuration
HOSTNAME="*"  # The subdomain you want to update, e.g., www.example.com

# Get the current public IP address
CURRENT_IP=$(curl -s ifconfig.me)
if [ -z "$CURRENT_IP" ]; then
  echo "[$(date)] Failed to retrieve current IP address."
  exit 1
fi
echo "[$(date)] Current IP address: ${CURRENT_IP}"

# Function to update DNS record
update_dns_record() {
  RESPONSE=$(curl -s "https://dynamicdns.park-your-domain.com/update?host=${HOSTNAME}&domain=${DOMAIN_NAME}&password=${DDNS_API_KEY}&ip=${CURRENT_IP}")
  echo "[$(date)] DNS update response: $RESPONSE"
}

# Function to check if the current IP matches the DNS record
check_dns_record() {
  DNS_IP=$(dig +short ${HOSTNAME}.${DOMAIN})
  if [ "$CURRENT_IP" == "$DNS_IP" ]; then
    echo "[$(date)] IP address has not changed. Current IP: $CURRENT_IP"
    exit 0
  else
    echo "[$(date)] IP address has changed. Updating DNS record."
    update_dns_record
  fi
}

# Check DNS record and update if necessary
check_dns_record
