# Stage 1: Python build stage
FROM mcr.microsoft.com/cbl-mariner/base/python:3.9 as builder

# Install required packages for building
RUN tdnf install -y gcc glibc-devel libffi-devel openssl-devel

# Install Python dependencies
RUN pip install --no-cache-dir cryptography

# Copy Python script
COPY generate_jwks.py /generate_jwks.py

# Stage 2: Final Nginx stage
FROM mcr.microsoft.com/cbl-mariner/base/nginx:1.22

# Copy Python from builder stage
COPY --from=builder /usr/bin/python3 /usr/bin/python3
COPY --from=builder /usr/lib/python3.9 /usr/lib/python3.9
COPY --from=builder /usr/lib64/libpython3.9.so.1.0 /usr/lib64/libpython3.9.so.1.0
COPY --from=builder /generate_jwks.py /generate_jwks.py

# Install necessary dependencies for Python
RUN tdnf install -y glibc libffi openssl

# Add Python to PATH
ENV PATH="/usr/bin:${PATH}"

# Copy other necessary files
COPY oidc-setup.sh /oidc-setup.sh
COPY generate_openid_configuration.sh /generate_openid_configuration.sh

# Make scripts executable
RUN chmod +x /oidc-setup.sh /generate_openid_configuration.sh

# Create necessary directories
RUN mkdir -p /var/www/html/.well-known /var/www/html/openid/v1

# Set correct permissions
RUN chown -R nginx:nginx /var/www/html

# Copy keys from mounted volume
VOLUME ["/keys"]

# Expose port
EXPOSE 8080

# Configure Nginx
COPY nginx.conf /etc/nginx/nginx.conf

# Set the entrypoint
ENTRYPOINT ["/bin/sh", "/oidc-setup.sh"]
