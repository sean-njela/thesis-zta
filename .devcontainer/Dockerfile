FROM ubuntu:22.04

# Install base tools
RUN apt-get update && apt-get install -y curl git unzip build-essential libssl-dev ca-certificates

# Install mise
RUN curl https://mise.run | sh
ENV PATH="/root/.local/bin:$PATH"

# Install Devbox
RUN curl -fsSL https://get.jetpack.io/devbox | bash
ENV PATH="/root/.devbox/bin:$PATH"

# Copy tool configs
COPY .tool-versions /root/.tool-versions
COPY devbox.json /workspace/devbox.json
WORKDIR /workspace

# Pre-install tools
ENTRYPOINT [ "bash", "-c", "devbox install && mise install && exec bash" ]
