FROM ubuntu:24.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV DISPLAY=:99

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    gnupg \
    curl \
    xvfb \
    x11vnc \
    matchbox-window-manager \
    novnc \
    websockify \
    socat \
    dbus-x11 \
    fonts-liberation \
    libasound2t64 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libwayland-client0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Install Chrome/Chromium based on architecture
# Google Chrome doesn't have ARM64 builds, use Chromium on ARM64
RUN if [ "$(dpkg --print-architecture)" = "amd64" ]; then \
        wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | gpg --dearmor > /usr/share/keyrings/google-linux-signing-keyring.gpg && \
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-linux-signing-keyring.gpg] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list && \
        apt-get update && \
        apt-get install -y --no-install-recommends google-chrome-stable && \
        rm -rf /var/lib/apt/lists/* && \
        ln -sf /usr/bin/google-chrome-stable /usr/bin/chrome; \
    else \
        apt-get update && \
        apt-get install -y --no-install-recommends chromium-browser && \
        rm -rf /var/lib/apt/lists/* && \
        ln -sf /usr/bin/chromium-browser /usr/bin/chrome; \
    fi

# Create data directory and generate machine-id for Chrome
RUN mkdir -p /data/chrome-profile && \
    dbus-uuidgen > /etc/machine-id

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Expose ports
EXPOSE 9222 6080

# Health check
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
    CMD curl -f http://localhost:9222/json/list || exit 1

CMD ["/entrypoint.sh"]
