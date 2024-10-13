#!/bin/sh

# Use OIDC_HOSTNAME environment variable, defaulting to 'localhost' if not set
HOSTNAME=${OIDC_HOSTNAME:-localhost}

# Ensure the directory exists
mkdir -p /var/www/html/.well-known

cat <<EOF > /var/www/html/.well-known/openid-configuration
{
  "issuer": "http://${HOSTNAME}:8080/",
  "jwks_uri": "http://${HOSTNAME}:8080/openid/v1/jwks",
  "response_types_supported": [
    "id_token"
  ],
  "subject_types_supported": [
    "public"
  ],
  "id_token_signing_alg_values_supported": [
    "RS256"
  ]
}
EOF
