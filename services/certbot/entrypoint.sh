#!/bin/bash

set -e

# Ensure the DOMAIN_NAME environment variable is set
if [ -z "$DOMAIN_NAME" ]; then
  echo "DOMAIN_NAME environment variable is not set. Exiting."
  exit 1
fi

# Function to request initial certificates
request_initial_certificates() {
  echo "Requesting initial certificates for $DOMAIN_NAME and www.$DOMAIN_NAME..."
  certbot certonly --webroot --webroot-path=/var/www/certbot -d "$DOMAIN_NAME" -d "www.$DOMAIN_NAME" --agree-tos --email $EMAIL_ADDRESS --non-interactive
}

# Check if certificates already exist
if [ ! -f /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem ]; then
  request_initial_certificates
fi

# Start the renewal process
echo "Starting the certificate renewal process..."
trap exit TERM; while :; do certbot renew; sleep 12h; done
