#!/bin/sh

# Configuration
HOSTNAME_WILDCARD="*"  # The subdomain you want to update, e.g., *.example.com
HOSTNAME_BASE="@"      # The base domain, typically '@' represents the root domain

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

# Get the current IP address from DNS
DNS_IP=$(dig +short ${DOMAIN_NAME})
if [ -z "$DNS_IP" ]; then
  echo "[$(date)] Failed to retrieve DNS IP address for ${DOMAIN_NAME}."
  exit 1
fi
echo "DNS_IP found: $DNS_IP"

if [ "$CURRENT_IP" = "$DNS_IP" ]; then
  echo "[$(date)] IP address for ${DOMAIN_NAME} has not changed. Current IP: $CURRENT_IP"
else
  echo "[$(date)] IP address for ${DOMAIN_NAME} has changed. Updating DNS record."

  # Update base domain
  RESPONSE_BASE=$(curl -s "https://dynamicdns.park-your-domain.com/update?host=${HOSTNAME_BASE}&domain=${DOMAIN_NAME}&password=${DDNS_API_KEY}&ip=${CURRENT_IP}")
  echo "[$(date)] DNS update response for ${HOSTNAME_BASE}.${DOMAIN_NAME}: $RESPONSE_BASE"
fi

DNS_IP=$(dig +short sub.${DOMAIN_NAME})
if [ -z "$DNS_IP" ]; then
  echo "[$(date)] Failed to retrieve DNS IP address for sub.${DOMAIN_NAME}."
  exit 1
fi
echo "DNS_IP found: $DNS_IP"

if [ "$CURRENT_IP" = "$DNS_IP" ]; then
  echo "[$(date)] IP address for sub.${DOMAIN_NAME} has not changed. Current IP: $CURRENT_IP"
else
  echo "[$(date)] IP address for sub.${DOMAIN_NAME} has changed. Updating DNS record."

  # Update wildcard subdomain
  RESPONSE_WILDCARD=$(curl -s "https://dynamicdns.park-your-domain.com/update?host=${HOSTNAME_WILDCARD}&domain=${DOMAIN_NAME}&password=${DDNS_API_KEY}&ip=${CURRENT_IP}")
  echo "[$(date)] DNS update response for ${HOSTNAME_WILDCARD}.${DOMAIN_NAME}: $RESPONSE_WILDCARD"
fi
