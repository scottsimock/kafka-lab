# Playwright MCP Setup

Playwright MCP exposes a Model Context Protocol server that lets AI agents
interact with the web application through a real browser. Agents can navigate
pages, click elements, fill forms, take screenshots, and read page content —
enabling AI-assisted test authoring, debugging, and exploratory testing.

## Prerequisites

- Node.js 20+
- Playwright browsers installed (`npx playwright install --with-deps chromium`)
- The `@playwright/mcp` dev dependency (already in `webapp/package.json`)

## Quick Start

### VS Code / Copilot Chat

The MCP server is pre-configured in `.vscode/mcp.json`. When you open the
project in VS Code with a Copilot Chat extension that supports MCP, the
Playwright server is available automatically. No manual startup needed.

### Manual / CLI

Start the MCP server from the webapp directory:

```bash
cd webapp
npm run mcp:playwright
```

Or directly:

```bash
npx @playwright/mcp --headless
```

The server launches a headless Chromium instance and exposes browser
automation tools over the MCP protocol via stdio.

## Configuration

### VS Code MCP Config (`.vscode/mcp.json`)

```json
{
  "servers": {
    "playwright": {
      "command": "npx",
      "args": ["@playwright/mcp@latest", "--headless"],
      "cwd": "${workspaceFolder}/webapp"
    }
  }
}
```

### Key Flags

| Flag | Purpose |
|---|---|
| `--headless` | Run browser without a visible window (required for CI and remote environments) |
| `--browser firefox` | Use Firefox instead of the default Chromium |
| `--port <N>` | Expose the MCP server over SSE transport on a specific port |

## Connecting to the Dev Environment

By default, Playwright MCP opens a blank page. Use the `browser_navigate` tool
to go to the target URL:

- **Local dev:** `http://localhost:3000`
- **Azure dev:** Set `PLAYWRIGHT_BASE_URL` and navigate to that URL

The base URL from `playwright.config.ts` (`PLAYWRIGHT_BASE_URL` env var) is
used by E2E tests but not automatically by the MCP server. Navigate explicitly
when using MCP.

## What AI Agents Can Do

Once the MCP server is running, agents have access to these browser tools:

| Tool | Description |
|---|---|
| `browser_navigate` | Go to a URL |
| `browser_click` | Click an element (by text, CSS selector, or coordinates) |
| `browser_type` | Type text into an input field |
| `browser_snapshot` | Get an accessibility snapshot of the current page |
| `browser_screenshot` | Capture a screenshot |
| `browser_wait` | Wait for a specified condition |
| `browser_go_back` | Navigate back |
| `browser_go_forward` | Navigate forward |
| `browser_tab_list` | List open browser tabs |
| `browser_tab_create` | Open a new tab |
| `browser_tab_select` | Switch to a specific tab |
| `browser_console_messages` | Read browser console output |
| `browser_network_requests` | Inspect network requests |
| `browser_file_upload` | Upload a file to a file input |
| `browser_pdf_save` | Save the page as PDF |

### Example: Smoke-Test the Dashboard

An AI agent might run these steps:

1. `browser_navigate` → `http://localhost:3000`
2. `browser_snapshot` → verify page structure and headings
3. `browser_click` → click "Topics" nav link
4. `browser_snapshot` → verify topic list renders
5. `browser_screenshot` → capture visual state for review

## Relationship to E2E Tests

Playwright MCP and the E2E test suite (`npx playwright test`) are independent:

| Aspect | E2E Tests | MCP Server |
|---|---|---|
| **Entry point** | `npm run test:e2e` | `npm run mcp:playwright` |
| **Config** | `playwright.config.ts` | `.vscode/mcp.json` |
| **Purpose** | Automated regression suite | Interactive AI-assisted exploration |
| **Browser** | Managed by test runner | Managed by MCP server |

Both use Chromium by default. They do not conflict — each manages its own
browser instance.

## Troubleshooting

### "Browser not found"

Install browsers:

```bash
npx playwright install --with-deps chromium
```

### MCP server not appearing in VS Code

- Confirm `.vscode/mcp.json` is valid JSON
- Reload VS Code window (`Ctrl+Shift+P` → "Reload Window")
- Check the Copilot Chat MCP panel for connection status

### Timeout connecting to dev environment

- Verify the webapp is running (`npm run dev`)
- Check that the URL is reachable from your machine
- For Azure deployments, ensure VPN/private network access is active

### Port conflicts

If another process uses the default port, start MCP with an explicit port:

```bash
npx @playwright/mcp --headless --port 8931
```
