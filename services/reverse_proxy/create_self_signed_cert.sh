#!/bin/bash

mkdir -p /etc/letsencrypt/selfsigned

openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/letsencrypt/selfsigned/privkey.pem \
  -out /etc/letsencrypt/selfsigned/fullchain.pem \
  -subj "/CN=localhost"
