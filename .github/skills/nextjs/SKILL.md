---
name: nextjs
description: Build the Kafka lab web application with Next.js 15 and TypeScript. Use when agents need to create pages, API route handlers, server components, client components, middleware, or configure the Next.js App Router for the Kafka management UI.
---

# Next.js

Next.js 15 is a React framework for building full-stack web applications. It uses the App Router with file-system routing, React Server Components by default, and supports API Route Handlers, Server Actions, and Middleware. The Kafka lab web application uses Next.js to provide a UI for managing topics, partitions, and messages.

## Key Concepts

### App Router

The App Router uses the `/app` directory for file-system routing. Folders become URL segments; `page.tsx` makes a segment routable; `layout.tsx` defines shared layouts that persist across navigations.

### Server Components

Components in `/app` are Server Components by default. They render on the server, can fetch data directly, and send minimal JavaScript to the browser. Use `'use client'` directive only for interactive components requiring browser APIs, state, or event handlers.

### Client Components

Marked with `'use client'` at the top of the file. Required for `useState`, `useEffect`, event handlers, and browser-only APIs. Keep Client Components as leaf nodes to minimize client-side JavaScript.

### Route Handlers

Replace the legacy `pages/api` pattern. Defined in `route.ts` files inside `/app/api/`. Support GET, POST, PUT, DELETE, and other HTTP methods as named exports.

### Server Actions

Server-side mutation functions invoked directly from Client Components. Declared with `'use server'` directive. Ideal for form submissions and data mutations.

### Middleware

Defined in `middleware.ts` at the project root (or `src/`). Runs on the Edge Runtime for every matching request. Use for authentication checks, redirects, and request logging.

## Project Structure

```text
src/
├── app/
│   ├── layout.tsx                  # Root layout (HTML shell)
│   ├── page.tsx                    # Home page
│   ├── api/
│   │   ├── topics/
│   │   │   └── route.ts           # GET/POST topics
│   │   └── topics/[name]/
│   │       ├── route.ts           # GET/DELETE single topic
│   │       └── messages/
│   │           └── route.ts       # GET/POST messages
│   ├── dashboard/
│   │   ├── layout.tsx             # Dashboard layout
│   │   ├── page.tsx               # Dashboard home
│   │   └── topics/
│   │       ├── page.tsx           # Topic list
│   │       └── [name]/
│   │           └── page.tsx       # Topic detail
│   └── (auth)/
│       ├── login/page.tsx
│       └── register/page.tsx
├── components/
│   ├── ui/                         # Reusable UI components
│   └── kafka/                      # Kafka-specific components
├── lib/
│   ├── kafka.ts                    # Kafka client utilities
│   └── api.ts                      # API client helpers
├── types/
│   └── kafka.ts                    # TypeScript type definitions
├── middleware.ts                    # Auth middleware
└── styles/
    └── globals.css
```

## Quick Start

See [getting-started/page.tsx](sample_codes/getting-started/page.tsx) for a Server Component page and [getting-started/route.ts](sample_codes/getting-started/route.ts) for an API Route Handler.

## Common Patterns

### API Route Handler with Kafka

See [common-patterns/topics-route.ts](sample_codes/common-patterns/topics-route.ts) for a route handler that manages Kafka topics.

### Client Component with Real-Time Data

See [common-patterns/message-viewer.tsx](sample_codes/common-patterns/message-viewer.tsx) for a client component that displays messages from a Kafka topic.

## Configuration

### `next.config.js`

```javascript
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  experimental: {
    serverActions: { bodySizeLimit: '2mb' },
  },
};
module.exports = nextConfig;
```

### Environment Variables

| Variable | Purpose | File |
|---|---|---|
| `KAFKA_BOOTSTRAP_SERVERS` | Broker addresses | `.env.local` |
| `SCHEMA_REGISTRY_URL` | Schema Registry endpoint | `.env.local` |
| `NEXT_PUBLIC_APP_URL` | Public app URL (client-accessible) | `.env.local` |

Variables prefixed with `NEXT_PUBLIC_` are exposed to the browser. Keep Kafka credentials server-only.

## Best Practices

- **Do**: Use Server Components by default; add `'use client'` only when needed
- **Do**: Fetch data in Server Components, not Client Components
- **Do**: Use Route Handlers for API endpoints, Server Actions for mutations
- **Do**: Keep `'use client'` components as leaf nodes in the component tree
- **Do**: Use TypeScript for type safety across Route Handlers and components
- **Do**: Use `output: 'standalone'` for containerized deployments
- **Avoid**: `'use client'` on layout or page components unless interactive
- **Avoid**: Exposing Kafka credentials via `NEXT_PUBLIC_` environment variables

## Troubleshooting

| Issue | Solution |
|---|---|
| "Text content does not match" hydration error | Ensure Server and Client render the same initial HTML |
| Route Handler returns 405 | Verify the exported function name matches the HTTP method (e.g., `GET`, `POST`) |
| Server Action not working | Verify `'use server'` directive is at the top of the function or file |
| Middleware not running | Check the `matcher` config in `middleware.ts` |

## Learn More

| Topic | How to Find |
|---|---|
| App Router docs | See [Next.js App Router](https://nextjs.org/docs/app) |
| Route Handlers | See [Route Handlers](https://nextjs.org/docs/app/building-your-application/routing/route-handlers) |
| Server Actions | See [Server Actions](https://nextjs.org/docs/app/building-your-application/data-fetching/server-actions-and-mutations) |
| Deployment | See [Deployment](https://nextjs.org/docs/app/building-your-application/deploying) |
