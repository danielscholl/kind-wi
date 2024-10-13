#!/bin/sh

set -e  # Exit immediately if a command exits with a non-zero status

# Ensure keys are available
if [ ! -f /keys/sa.pub ]; then
  echo "Error: Public key not found in /keys/sa.pub"
  exit 1
fi

# Create directories for OIDC documents
mkdir -p /var/www/html/.well-known
mkdir -p /var/www/html/openid/v1

# Generate OIDC discovery document
/bin/sh /generate_openid_configuration.sh

# Generate JWKS using the public key
/usr/bin/python3 /generate_jwks.py

# Check Nginx configuration
nginx -t

# Start Nginx
exec nginx -g 'daemon off;'
