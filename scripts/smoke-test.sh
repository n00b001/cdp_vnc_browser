#!/bin/bash
# =============================================================================
# Chrome CDP + noVNC Docker Smoke Test
# =============================================================================
# This script:
# 1. Builds Docker image
# 2. Starts container
# 3. Waits for services to be healthy
# 4. Runs basic health checks
# 5. Cleans up
#
# Usage:
#   IMAGE_TAG=myimage:latest ./smoke-test.sh
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
IMAGE_TAG="${IMAGE_TAG:-chrome-cdp-novnc:smoke-test}"
TEST_TIMEOUT=120
CONTAINER_NAME="chrome-test"

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Display configuration
log_info "Smoke Test Configuration:"
echo "  IMAGE_TAG: ${IMAGE_TAG}"
echo "  TEST_TIMEOUT: ${TEST_TIMEOUT}s"
echo ""

# Cleanup function
cleanup() {
    log_info "Cleaning up test environment..."
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
}

# Set trap to cleanup on exit
trap cleanup EXIT

# =============================================================================
# Test 1: Use/Build Docker Image
# =============================================================================
log_info "Test 1: Checking Docker image..."

if docker image inspect "$IMAGE_TAG" > /dev/null 2>&1; then
    log_success "Docker image exists"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_error "Docker image not found: $IMAGE_TAG"
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

# =============================================================================
# Test 2: Start Container
# =============================================================================
log_info "Test 2: Starting container..."

if docker run -d --name "$CONTAINER_NAME" \
    --shm-size=2g \
    --cap-add=SYS_ADMIN \
    -p 9222:9222 \
    -p 6080:6080 \
    "$IMAGE_TAG" > /tmp/container.log 2>&1; then
    log_success "Container started"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_error "Failed to start container"
    cat /tmp/container.log
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

# =============================================================================
# Test 3: Wait for Health Check
# =============================================================================
log_info "Test 3: Waiting for health check (timeout: ${TEST_TIMEOUT}s)..."

START_TIME=$(date +%s)
HEALTHY=0

while [ $(($(date +%s) - START_TIME)) -lt $TEST_TIMEOUT ]; do
    if docker ps | grep "$CONTAINER_NAME" | grep -q healthy; then
        HEALTHY=1
        break
    fi

    # Show container logs if it's restarting
    STATUS=$(docker inspect "$CONTAINER_NAME" --format='{{.State.Status}}' 2>/dev/null)
    if [ "$STATUS" = "exited" ]; then
        log_error "Container exited unexpectedly"
        log_info "Container logs:"
        docker logs "$CONTAINER_NAME" --tail 50
        TESTS_FAILED=$((TESTS_FAILED + 1))
        exit 1
    fi

    echo -n "."
    sleep 2
done

echo ""

if [ $HEALTHY -eq 1 ]; then
    log_success "Health check passed"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_error "Health check timed out after ${TEST_TIMEOUT}s"
    log_info "Container logs:"
    docker logs "$CONTAINER_NAME" --tail 100
    TESTS_FAILED=$((TESTS_FAILED + 1))
    exit 1
fi

# Wait a bit more for services to fully start
sleep 10

# =============================================================================
# Test 4: Chrome Binary Test
# =============================================================================
log_info "Test 4: Testing Chrome binary..."

if docker exec "$CONTAINER_NAME" /usr/bin/chrome --version > /dev/null 2>&1; then
    log_success "Chrome binary is working"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_error "Chrome binary test failed"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# =============================================================================
# Test 5: CDP Endpoint Test
# =============================================================================
log_info "Test 5: Testing CDP endpoint..."

HTTP_SUCCESS=0
for _ in 1 2 3; do
    if curl -sf http://localhost:9222/json/list > /dev/null 2>&1; then
        HTTP_SUCCESS=1
        break
    fi
    sleep 2
done

if [ $HTTP_SUCCESS -eq 1 ]; then
    log_success "CDP endpoint responds"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_error "CDP endpoint failed"
    log_info "Trying to get more info..."
    curl -v http://localhost:9222/json/list 2>&1 || true
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# =============================================================================
# Test 6: noVNC Test
# =============================================================================
log_info "Test 6: Testing noVNC..."

if curl -sf http://localhost:6080/ > /dev/null 2>&1; then
    log_success "noVNC is accessible"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_error "noVNC is not accessible"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# =============================================================================
# Test 7: Container Process Test
# =============================================================================
log_info "Test 7: Checking container processes..."

if docker exec "$CONTAINER_NAME" pgrep chrome > /dev/null 2>&1; then
    log_success "Chrome process is running"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_error "Chrome process not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

if docker exec "$CONTAINER_NAME" pgrep Xvfb > /dev/null 2>&1; then
    log_success "Xvfb process is running"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    log_error "Xvfb process not found"
    TESTS_FAILED=$((TESTS_FAILED + 1))
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo "========================================"
echo "Smoke Test Summary"
echo "========================================"
echo "Image: ${IMAGE_TAG}"
echo "----------------------------------------"
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo "========================================"

if [ $TESTS_FAILED -eq 0 ]; then
    log_success "All smoke tests passed!"
    exit 0
else
    log_error "Some smoke tests failed"
    exit 1
fi
