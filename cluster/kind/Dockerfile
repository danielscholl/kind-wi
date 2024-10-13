FROM docker:20.10.8-dind

# Install dependencies
RUN apk add --no-cache \
    bash \
    curl \
    git \
    openssl \
    iptables

# Install kind
RUN curl -Lo /usr/local/bin/kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64 && \
    chmod +x /usr/local/bin/kind

# Install kubectl
RUN curl -Lo /usr/local/bin/kubectl https://dl.k8s.io/release/v1.22.4/bin/linux/amd64/kubectl && \
    chmod +x /usr/local/bin/kubectl

# Copy the startup script
COPY start-kind.sh /start-kind.sh
RUN chmod +x /start-kind.sh

ENTRYPOINT ["/start-kind.sh"]
