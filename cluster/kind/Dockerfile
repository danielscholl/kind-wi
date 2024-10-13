FROM docker:dind

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    git \
    openssl \
    iptables

# Install kind
RUN curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.24.0/kind-linux-amd64 && \
    chmod +x /usr/local/bin/kind

# Install kubectl
RUN curl -Lo /usr/local/bin/kubectl https://dl.k8s.io/release/v1.31.1/bin/linux/amd64/kubectl && \
    chmod +x /usr/local/bin/kubectl

# Copy the startup script
COPY start-kind.sh /start-kind.sh
RUN chmod +x /start-kind.sh

ENTRYPOINT ["/start-kind.sh"]
