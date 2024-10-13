FROM python:3.9-slim

# Install required packages
RUN apt-get update && apt-get install -y curl && \
    pip install --no-cache-dir flask cryptography && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy all necessary files
COPY oidc-setup.sh /oidc-setup.sh
COPY generate_openid_configuration.sh /generate_openid_configuration.sh
COPY generate_jwks.py /generate_jwks.py
COPY oidc_server.py /oidc_server.py

# Make scripts executable
RUN chmod +x /oidc-setup.sh /generate_openid_configuration.sh

# Copy keys from mounted volume
VOLUME ["/keys"]

# Create necessary directories
RUN mkdir -p /oidc/.well-known /oidc/openid/v1

# Expose port
EXPOSE 8080

ENTRYPOINT ["/oidc-setup.sh"]
