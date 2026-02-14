# Chrome CDP + noVNC Docker Stack

A Docker container that provides:
- **Chrome DevTools Protocol (CDP)** exposed on the network for browser automation
- **noVNC web interface** to see and interact with the browser (solve captchas manually)
- **Persistent browser data** (cookies, localStorage, cache survive restarts)
- **Auto-start** Chrome is running when the container starts

## Quick Start

### Option 1: Use Pre-built Image from GitHub Packages

```bash
# Pull and run the pre-built image
docker run -d \
  --name chrome-cdp-novnc \
  --shm-size=2g \
  --cap-add=SYS_ADMIN \
  --security-opt seccomp=unconfined \
  -p 9222:9222 \
  -p 6080:6080 \
  -v $(pwd)/chrome-data:/data/chrome-profile \
  ghcr.io/xfanth/cdp_vnc_browser:latest
```

### Option 2: Build Locally

```bash
# Clone or copy these files to a directory, then:
docker-compose up -d --build

# Or with docker build directly:
docker build -t chrome-cdp-novnc .
docker run -d \
  --name chrome-cdp-novnc \
  --shm-size=2g \
  --cap-add=SYS_ADMIN \
  --security-opt seccomp=unconfined \
  -p 9222:9222 \
  -p 6080:6080 \
  -v $(pwd)/chrome-data:/data/chrome-profile \
  chrome-cdp-novnc
```

## Access Points

| Service | URL | Purpose |
|---------|-----|---------|
| **CDP** | `http://localhost:9222` | Connect your automation code (Puppeteer, Playwright, chromedp, etc.) |
| **noVNC** | `http://localhost:6080` | Open in browser to see and interact with Chrome |
| **CDP JSON** | `http://localhost:9222/json/list` | List available pages/targets |

## Usage Examples

### Puppeteer (Node.js)

```javascript
const puppeteer = require('puppeteer');

async function main() {
  // Connect to remote Chrome via CDP
  const browser = await puppeteer.connect({
    browserURL: 'http://localhost:9222'
  });
  
  // Get existing page or create new one
  const pages = await browser.pages();
  const page = pages[0] || await browser.newPage();
  
  await page.goto('https://example.com');
  
  // When you hit a captcha, switch to noVNC at http://localhost:6080
  // to solve it manually, then continue automation
  
  // Don't close browser - just disconnect to keep Chrome running
  browser.disconnect();
}

main();
```

### Playwright (Node.js)

```javascript
const { chromium } = require('playwright');

async function main() {
  const browser = await chromium.connectOverCDP('http://localhost:9222');
  const context = browser.contexts()[0];
  const page = context.pages()[0] || await context.newPage();
  
  await page.goto('https://example.com');
  
  // Solve captchas via noVNC at http://localhost:6080
  
  browser.close();
}

main();
```

### chromedp (Go)

```go
package main

import (
    "context"
    "fmt"
    "log"

    "github.com/chromedp/chromedp"
)

func main() {
    // Connect to remote Chrome
    allocCtx, cancel := chromedp.NewRemoteAllocator(context.Background(), "ws://localhost:9222")
    defer cancel()
    
    ctx, cancel := chromedp.NewContext(allocCtx)
    defer cancel()
    
    var result string
    err := chromedp.Run(ctx,
        chromedp.Navigate("https://example.com"),
        chromedp.Title(&result),
    )
    if err != nil {
        log.Fatal(err)
    }
    fmt.Println("Title:", result)
}
```

### Python (pyppeteer)

```python
import asyncio
from pyppeteer import connect

async def main():
    browser = await connect(browserURL='http://localhost:9222')
    page = await browser.newPage()
    await page.goto('https://example.com')
    # Solve captcha via noVNC at http://localhost:6080
    # ... continue automation

asyncio.get_event_loop().run_until_complete(main())
```

## Solving Captchas

1. Your automation script navigates to a page with a captcha
2. **Switch to noVNC** at `http://localhost:6080` in your browser
3. **Click inside the noVNC window** to interact with Chrome
4. **Solve the captcha manually** using your mouse/keyboard
5. Your automation script can then continue

## Persistence

Browser data is persisted in `./chrome-data/` (mapped to `/data/chrome-profile` in the container):
- Cookies
- localStorage/sessionStorage
- IndexedDB
- Browser cache
- Session restore data

To reset to a clean state:
```bash
docker-compose down
rm -rf ./chrome-data
docker-compose up -d
```

## Troubleshooting

### Container won't start / Chrome crashes
```bash
# Check logs
docker-compose logs -f

# Try with more shared memory
# Edit docker-compose.yml: shm_size: "4gb"
```

### CDP not accessible from other machines
Make sure you're binding to `0.0.0.0` not `127.0.0.1`:
```yaml
ports:
  - "0.0.0.0:9222:9222"  # Bind to all interfaces
```

### noVNC shows black screen
```bash
# Check if Xvfb is running
docker exec -it chrome-cdp-novnc ps aux | grep Xvfb

# Check Chrome process
docker exec -it chrome-cdp-novnc ps aux | grep chrome

# Check logs
docker-compose logs chrome
```

### Chrome is slow / unresponsive
Increase shared memory in docker-compose.yml:
```yaml
shm_size: "4gb"
```

## Files

```
.
├── docker-compose.yml   # Docker Compose configuration
├── Dockerfile           # Container image definition
├── entrypoint.sh        # Container entrypoint script
└── README.md            # This file
```

## Automated Builds

This repository includes a GitHub Actions workflow that automatically builds and publishes Docker images to GitHub Packages on every push to `main`.

- **Registry**: `ghcr.io` (GitHub Container Registry)
- **Image**: `ghcr.io/xfanth/cdp_vnc_browser`
- **Tags**: `latest`, commit SHA, and branch name

To use the pre-built image:
```bash
docker pull ghcr.io/xfanth/cdp_vnc_browser:latest
```

## Security Notes

- This setup is designed for **development/testing** environments
- CDP is exposed on all interfaces (`0.0.0.0`) - use firewall rules in production
- noVNC has no password protection - add `--websockify-options="--web" --web /usr/share/novnc` with auth if needed
- For production, consider adding authentication to noVNC

