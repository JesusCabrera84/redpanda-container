FROM ubuntu:22.04

# Avoid prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Update and install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    ca-certificates \
    lsb-release \
    iproute2 \
    net-tools \
    procps \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# Install Redpanda
RUN curl -1sLf 'https://dl.redpanda.com/public/redpanda/setup.deb.sh' | bash \
    && apt-get install -y redpanda

# Copy setup script
COPY setup-redpanda.sh /usr/local/bin/setup-redpanda.sh
RUN chmod +x /usr/local/bin/setup-redpanda.sh

# This container is meant for development and CI
CMD ["/usr/local/bin/setup-redpanda.sh"]

