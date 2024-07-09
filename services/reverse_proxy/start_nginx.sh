#!/bin/bash

echo "Starting the NGINX setup script..."

# Ensure the DOMAIN_NAME environment variable is set
if [ -z "$DOMAIN_NAME" ]; then
  echo "ERROR: DOMAIN_NAME environment variable is not set. Exiting."
  exit 1
fi

echo "DOMAIN_NAME is set to $DOMAIN_NAME"

# Paths to the real certificates
REAL_CERT_PATH="/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem"
REAL_KEY_PATH="/etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem"

echo "Checking if real certificates are available at $REAL_CERT_PATH and $REAL_KEY_PATH..."

# Generate a self-signed certificate
echo "Generating a self-signed certificate..."
/create_self_signed_cert.sh

# Substitute environment variables in the NGINX configuration template for self-signed certificates
echo "Substituting environment variables in the NGINX configuration template..."
envsubst '${DOMAIN_NAME}' < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

echo "Starting NGINX with the self-signed certificate..."
nginx -g 'daemon off;' &
NGINX_PID=$!

# Wait until the real certificates are available
echo "Waiting for real certificates to become available..."
while [ ! -f "$REAL_CERT_PATH" ] || [ ! -f "$REAL_KEY_PATH" ]; do
  echo "Real certificates not found. Sleeping for 5 seconds..."
  sleep 5
done

echo "Real certificates are now available."

echo "Rewriting NGINX config to use real certificates..."
sed -i 's|/etc/letsencrypt/selfsigned/fullchain.pem|'"$REAL_CERT_PATH"'|g' /etc/nginx/nginx.conf
sed -i 's|/etc/letsencrypt/selfsigned/privkey.pem|'"$REAL_KEY_PATH"'|g' /etc/nginx/nginx.conf

echo "Reloading NGINX with the real certificates..."
nginx -s reload

wait $NGINX_PID
echo "NGINX setup script completed."
