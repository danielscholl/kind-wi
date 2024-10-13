#!/bin/bash

# Ensure keys are available
if [ ! -f /keys/sa.pub ]; then
  echo "Public key not found in /keys/sa.pub"
  exit 1
fi

# Create directories for OIDC documents
mkdir -p /oidc/.well-known
mkdir -p /oidc/openid/v1

# Generate OIDC discovery document
./generate_openid_configuration.sh

# Generate JWKS using the public key
python generate_jwks.py

# Run a simple Flask server to serve the OIDC documents
export FLASK_APP=oidc_server.py
flask run --host=0.0.0.0 --port=8080
