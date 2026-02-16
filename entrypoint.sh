#!/bin/bash
set -e

echo "=== Starting Chrome CDP + noVNC Container ==="

# Clean up any stale locks
rm -rf /tmp/.X99-lock 2>/dev/null || true
rm -rf /tmp/.X11-unix 2>/dev/null || true

# Create directories
mkdir -p /data/chrome-profile

# Clean up stale Chrome profile locks (from previous sessions)
echo "Cleaning up stale Chrome profile locks..."
rm -f /data/chrome-profile/SingletonLock 2>/dev/null || true
rm -f /data/chrome-profile/SingletonSocket 2>/dev/null || true
rm -f /data/chrome-profile/SingletonCookie 2>/dev/null || true
rm -rf /data/chrome-profile/SingletonSocket 2>/dev/null || true

# Start Xvfb
echo "Starting Xvfb..."
Xvfb :99 -screen 0 1920x1080x24 -ac &
XVFB_PID=$!

# Wait for Xvfb to be ready
echo "Waiting for Xvfb to be ready..."
for _ in {1..30}; do
    if xdpyinfo -display :99 >/dev/null 2>&1; then
        echo "Xvfb is ready"
        break
    fi
    sleep 0.5
done

if ! xdpyinfo -display :99 >/dev/null 2>&1; then
    echo "WARNING: Xvfb failed to respond, but continuing..."
    echo "This may be a timing issue in CI environments"
    echo "Chrome will still try to start without a functional X display"
fi

# Start matchbox-window-manager (borderless, no titlebar)
echo "Starting Matchbox Window Manager..."
matchbox-window-manager -use_titlebar no -use_cursor yes &
sleep 1

# Start x11vnc
echo "Starting x11vnc..."
x11vnc -display :99 -forever -shared -rfbport 5900 -nopw -bg 2>/dev/null
sleep 1

# Start noVNC
echo "Starting noVNC..."
/usr/share/novnc/utils/launch.sh --vnc localhost:5900 --listen 6080 2>/dev/null &
NOVNC_PID=$!
sleep 2

# Start Chrome (on internal port 9223)
# Extensions ENABLED, full UI visible
echo "Starting Chrome..."
/usr/bin/chrome \
    --no-first-run \
    --no-default-browser-check \
    --disable-background-networking \
    --disable-client-side-phishing-detection \
    --disable-default-apps \
    --disable-hang-monitor \
    --disable-popup-blocking \
    --disable-prompt-on-repost \
    --disable-sync \
    --disable-translate \
    --metrics-recording-only \
    --disable-gpu \
    --disable-software-rasterizer \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-setuid-sandbox \
    --remote-debugging-port=9223 \
    --user-data-dir=/data/chrome-profile \
    --window-size=1920,1080 \
    --window-position=0,0 \
    about:blank &

CHROME_PID=$!

# Wait for Chrome CDP to be ready
echo "Waiting for Chrome CDP to be ready..."
for _ in {1..30}; do
    if ! kill -0 $CHROME_PID 2>/dev/null; then
        echo "ERROR: Chrome process died!"
        exit 1
    fi

    if curl -s http://127.0.0.1:9223/json/list > /dev/null 2>&1; then
        echo "Chrome CDP is ready on internal port 9223"
        break
    fi
    sleep 0.5
done

if ! curl -s http://127.0.0.1:9223/json/list > /dev/null 2>&1; then
    echo "ERROR: Chrome CDP failed to start"
    exit 1
fi

# Start socat AFTER Chrome is ready
echo "Starting socat port forwarder..."
echo "  External: 0.0.0.0:9222 -> Internal: 127.0.0.1:9223"
socat TCP-LISTEN:9222,reuseaddr,fork TCP:127.0.0.1:9223 &
SOCAT_PID=$!

echo ""
echo "=== Container Ready ==="
echo "CDP Endpoint:    http://localhost:9222"
echo "CDP JSON List:   http://localhost:9222/json/list"
echo "noVNC Web:       http://localhost:6080/vnc.html"
echo ""
echo "✓ Chrome CDP accessible on port 9222 (via socat proxy)"

# Keep container running
trap 'echo "Shutting down..."; kill $SOCAT_PID $CHROME_PID $NOVNC_PID $XVFB_PID 2>/dev/null; exit 0' SIGTERM SIGINT

wait $CHROME_PID
