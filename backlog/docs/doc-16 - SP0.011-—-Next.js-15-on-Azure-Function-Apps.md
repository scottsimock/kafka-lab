---
id: doc-16
title: SP0.011 — Next.js 15 on Azure Function Apps
type: other
created_date: '2026-03-30 16:09'
---
# SP0.011 — Next.js 15 on Azure Function Apps

## Executive Summary

The Kafka Lab web application is a Next.js 15 management dashboard that provides real-time visibility into Kafka cluster health, topic configuration, consumer group lag, and message browsing. It runs as a server-side rendered (SSR) application deployed to Azure Function Apps using the custom handler pattern with Next.js `output: 'standalone'`, connected to private Kafka brokers via regional VNet integration.

**Tech stack:**

| Layer | Technology |
|---|---|
| Framework | Next.js 15, App Router, TypeScript |
| Kafka client | `@confluentinc/kafka-javascript` (KafkaJS-compatible promisified API) |
| Hosting | Azure Function Apps (Premium plan) with custom handler |
| Network | Regional VNet integration → private endpoints to Kafka |
| CDN / ingress | Azure Front Door (TLS termination, static asset caching) |
| Auth | User Assigned Managed Identity (UAMI) for Key Vault and Azure resources |

**Four dashboard views:**

1. **Cluster Overview** — broker status, partition distribution, replication health
2. **Topic Detail** — per-topic partitions, offsets, and configuration
3. **Consumer Groups** — lag monitoring and member assignment
4. **Message Browser** — produce and consume messages with schema support

---

## Next.js 15 App Router Patterns

### Server vs. Client Components

All components in the `app/` directory are Server Components by default. They render on the server, can directly call Kafka API utilities or backend logic, and ship only HTML to the browser — no client-side JavaScript bundle. Client Components are opted in with `'use client'` and are restricted to interactive UI elements.

**Decision rule:** Keep Server Components high in the tree; push Client Components as low as possible.

```typescript
// app/dashboard/page.tsx — Server Component (default)
// Fetches data at request time, no client JS shipped
export default async function DashboardPage() {
  const brokers = await fetchBrokerStatus(); // direct backend call
  return <ClusterOverview brokers={brokers} />;
}
```

```typescript
// components/RefreshButton.tsx — Client Component
'use client';
import { useTransition } from 'react';

export function RefreshButton({ onRefresh }: { onRefresh: () => void }) {
  const [isPending, startTransition] = useTransition();
  return (
    <button onClick={() => startTransition(onRefresh)} disabled={isPending}>
      {isPending ? 'Refreshing…' : 'Refresh'}
    </button>
  );
}
```

### API Route Handlers

Route Handlers (`app/api/**/route.ts`) expose REST endpoints using the Web `Request`/`Response` APIs. They are the primary integration point between the browser and the Kafka client. Dynamic segments in the path resolve as `Promise<{ param: string }>` in Next.js 15.

```typescript
// app/api/topics/[name]/route.ts
import { NextRequest } from 'next/server';

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ name: string }> }
) {
  const { name } = await params;
  // ... call Kafka admin client
}
```

### Layouts and Nested Routing

Layouts in `app/layout.tsx` wrap all child pages and persist across navigation without remounting. Dashboard sub-views live under `app/dashboard/(views)/` using route groups.

```
app/
  layout.tsx           ← root layout (nav, auth context)
  dashboard/
    layout.tsx         ← dashboard shell (sidebar, header)
    (views)/
      overview/page.tsx
      topics/
        page.tsx
        [name]/page.tsx
      consumer-groups/page.tsx
      messages/page.tsx
    loading.tsx        ← Suspense fallback for entire dashboard
    error.tsx          ← Error boundary for dashboard
```

### Streaming and Suspense

Use React `Suspense` with async Server Components to stream data progressively. The Message Browser view streams consumed messages using the Web Streams API from a Route Handler.

```typescript
// app/api/messages/stream/route.ts
export async function GET(req: NextRequest) {
  const encoder = new TextEncoder();
  const stream = new ReadableStream({
    async start(controller) {
      // consume Kafka messages and enqueue as SSE
      for await (const msg of consumeMessages(req)) {
        controller.enqueue(encoder.encode(`data: ${JSON.stringify(msg)}\n\n`));
      }
      controller.close();
    },
  });
  return new Response(stream, {
    headers: { 'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache' },
  });
}
```

### Error Boundaries

Place `error.tsx` files at each route segment to catch and display errors without crashing the full page. These are Client Components.

```typescript
// app/dashboard/error.tsx
'use client';
export default function DashboardError({ error, reset }: {
  error: Error;
  reset: () => void;
}) {
  return (
    <div>
      <p>Failed to load dashboard: {error.message}</p>
      <button onClick={reset}>Retry</button>
    </div>
  );
}
```

---

## Kafka API Routes

All Kafka operations use `@confluentinc/kafka-javascript` (KafkaJS-compatible promisified API). A shared singleton client module initialises once per Function App warm instance and is reused across requests.

### Shared Client Module

```typescript
// lib/kafka/client.ts
import { Kafka } from '@confluentinc/kafka-javascript';

let kafka: Kafka | null = null;

export function getKafkaClient(): Kafka {
  if (!kafka) {
    kafka = new Kafka({
      brokers: process.env.KAFKA_BOOTSTRAP_SERVERS!.split(','),
      ssl: true,
      sasl: {
        mechanism: 'plain',
        username: process.env.KAFKA_USERNAME!,
        password: process.env.KAFKA_PASSWORD!,
      },
    });
  }
  return kafka;
}
```

### List Topics (Admin Client)

```typescript
// app/api/topics/route.ts
import { NextResponse } from 'next/server';
import { getKafkaClient } from '@/lib/kafka/client';

export async function GET() {
  const admin = getKafkaClient().admin();
  await admin.connect();
  try {
    const metadata = await admin.fetchTopicMetadata();
    const topics = metadata.topics.map((t) => ({
      name: t.name,
      partitions: t.partitions.length,
    }));
    return NextResponse.json({ topics });
  } finally {
    await admin.disconnect();
  }
}
```

### Topic Detail (Offsets + Config)

```typescript
// app/api/topics/[name]/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getKafkaClient } from '@/lib/kafka/client';

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ name: string }> }
) {
  const { name } = await params;
  const admin = getKafkaClient().admin();
  await admin.connect();
  try {
    const [metadata, offsets, configs] = await Promise.all([
      admin.fetchTopicMetadata({ topics: [name] }),
      admin.fetchTopicOffsets(name),
      admin.describeConfigs({
        resources: [{ type: 2, name }], // 2 = TOPIC
        includeSynonyms: false,
      }),
    ]);
    return NextResponse.json({ metadata, offsets, configs });
  } finally {
    await admin.disconnect();
  }
}
```

### Consumer Group Lag

```typescript
// app/api/consumer-groups/[groupId]/lag/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getKafkaClient } from '@/lib/kafka/client';

export async function GET(
  _req: NextRequest,
  { params }: { params: Promise<{ groupId: string }> }
) {
  const { groupId } = await params;
  const admin = getKafkaClient().admin();
  await admin.connect();
  try {
    const description = await admin.describeGroups([groupId]);

    // Extract topics assigned to this consumer group from member assignments
    const topics = Array.from(
      new Set(
        description.groups
          .flatMap((g) => g.members)
          .flatMap((m) => (m.memberAssignment?.assignedPartitions ?? []).map((a: { topic: string }) => a.topic))
      )
    );

    const lag: Record<string, number> = {};
    for (const topic of topics) {
      const [committed, endOffsets] = await Promise.all([
        admin.fetchOffsets({ groupId, topics: [topic] }),
        admin.fetchTopicOffsets(topic),
      ]);
      for (const ep of endOffsets) {
        const committedOffset = parseInt(
          committed
            .find((c) => c.topic === topic)
            ?.partitions.find((p) => p.partition === ep.partition)
            ?.offset ?? '0',
          10
        );
        lag[`${topic}[${ep.partition}]`] = Math.max(0, parseInt(ep.offset, 10) - committedOffset);
      }
    }
    return NextResponse.json({ groupId, description, lag });
  } finally {
    await admin.disconnect();
  }
}
```

### Produce Message

```typescript
// app/api/messages/produce/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getKafkaClient } from '@/lib/kafka/client';

export async function POST(req: NextRequest) {
  const { topic, key, value, headers } = await req.json();
  const producer = getKafkaClient().producer();
  await producer.connect();
  try {
    const result = await producer.send({
      topic,
      messages: [{ key, value, headers }],
    });
    return NextResponse.json({ result });
  } finally {
    await producer.disconnect();
  }
}
```

### Consume Messages (Latest N)

```typescript
// app/api/messages/consume/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getKafkaClient } from '@/lib/kafka/client';

export async function GET(req: NextRequest) {
  const { searchParams } = new URL(req.url);
  const topic = searchParams.get('topic')!;
  const limit = parseInt(searchParams.get('limit') ?? '20', 10);

  const consumer = getKafkaClient().consumer({ groupId: `kafka-lab-browser-${Date.now()}` });
  await consumer.connect();
  await consumer.subscribe({ topic, fromBeginning: false });

  const messages: unknown[] = [];
  await new Promise<void>((resolve) => {
    consumer.run({
      eachMessage: async ({ message }) => {
        messages.push({
          key: message.key?.toString(),
          value: message.value?.toString(),
          timestamp: message.timestamp,
          headers: message.headers,
        });
        if (messages.length >= limit) resolve();
      },
    });
    setTimeout(resolve, 5000); // 5 s timeout
  });

  await consumer.disconnect();
  return NextResponse.json({ messages });
}
```

---

## Azure Function Apps for Next.js SSR

### Deployment Model

Azure Function Apps do not natively host Node.js HTTP servers, but the **custom handler** pattern bridges this gap. The Next.js standalone output produces a self-contained `server.js` that is launched as the custom handler executable. The Functions host proxies all HTTP requests to it.

**Build pipeline output:**

```
.next/standalone/     ← self-contained Node.js server
  server.js           ← custom handler entry point
  .next/
  node_modules/       ← pruned production deps only
public/               ← static assets (copied in during build)
host.json
local.settings.json
```

### next.config.ts

```typescript
import type { NextConfig } from 'next';

const nextConfig: NextConfig = {
  output: 'standalone',
  // Compress responses at Function App level; disable built-in
  compress: false,
};

export default nextConfig;
```

### host.json

```json
{
  "version": "2.0",
  "customHandler": {
    "description": {
      "defaultExecutablePath": "node",
      "arguments": [".next/standalone/server.js"],
      "workingDirectory": ""
    },
    "enableForwardingHttpRequest": true
  },
  "extensionBundle": {
    "id": "Microsoft.Azure.Functions.ExtensionBundle",
    "version": "[4.*, 5.0.0)"
  }
}
```

### local.settings.json (development)

```json
{
  "IsEncrypted": false,
  "Values": {
    "FUNCTIONS_WORKER_RUNTIME": "Custom",
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "KAFKA_BOOTSTRAP_SERVERS": "localhost:9092"
  }
}
```

### Function App Plan Requirements

| Requirement | Setting |
|---|---|
| Plan | Premium (EP1 minimum) or Dedicated |
| Node.js runtime | 20 LTS |
| VNet integration | Regional VNet integration enabled |
| Always Ready instances | ≥ 1 (eliminates cold starts for primary region) |

The **Consumption plan is not suitable** — it does not support VNet integration.

### Cold Start Optimisation

- **`output: 'standalone'`** prunes dependencies to only production-required modules, reducing package size from ~200 MB to ~30–50 MB.
- **Always Ready instances** on the Premium plan keep at least one instance warm, eliminating cold start latency for normal traffic.
- **Module-level singleton** for the Kafka client (`lib/kafka/client.ts`) avoids reconnect overhead on warm invocations.
- **Route segment `export const dynamic = 'force-dynamic'`** only on routes that require it; allow static pre-rendering where possible.
- **Lazy admin client connections** — connect on first request, disconnect in `finally` block to avoid keeping long-lived connections across idle periods.

---

## VNet Integration

### Architecture

```
[Azure Front Door] → [Function App (Premium)] → [VNet integration subnet]
                                                          │
                                              [Private DNS Zone]
                                                          │
                                              [Kafka Private Endpoint NIC]
                                                          │
                                              [Kafka VM Subnet (southcentralus)]
```

### Regional VNet Integration

Regional VNet integration gives the Function App **outbound** access to resources in the VNet. It requires:

1. A **delegation subnet** in the VNet dedicated to the Function App (`Microsoft.Web/serverFarms`).
2. VNet integration enabled on the Function App (Terraform: `virtual_network_subnet_id`).
3. `WEBSITE_VNET_ROUTE_ALL = 1` app setting to route all outbound traffic through the VNet (required for private endpoint DNS resolution).

```hcl
resource "azapi_resource" "function_app_vnet_config" {
  type      = "Microsoft.Web/sites/networkConfig@2023-12-01"
  parent_id = azapi_resource.function_app.id
  name      = "virtualNetwork"
  body = {
    properties = {
      subnetResourceId = var.function_delegation_subnet_id
      swiftSupported   = true
    }
  }
}
```

### Private DNS Resolution

When `WEBSITE_VNET_ROUTE_ALL = 1` is set, the Function App uses the VNet's DNS resolver. The private DNS zone for Kafka (e.g., `privatelink.kafka.example.internal`) must be **linked to the VNet** so that broker hostnames resolve to private endpoint IPs.

**DNS flow:**

```
Function App → VNet DNS (168.63.129.16)
            → Private DNS Zone (broker.kafka.example.internal → 10.0.3.4)
            → Private Endpoint NIC (10.0.3.4)
            → Kafka broker VM
```

### Kafka Bootstrap Servers Configuration

Kafka broker hostnames in `KAFKA_BOOTSTRAP_SERVERS` must match the names registered in the private DNS zone. Do **not** use raw IP addresses — the TLS certificate is issued against hostnames.

```
KAFKA_BOOTSTRAP_SERVERS=broker-1.kafka.example.internal:9093,broker-2.kafka.example.internal:9093
```

### NSG Rules (Function → Kafka)

| Direction | Source | Destination | Port | Protocol |
|---|---|---|---|---|
| Outbound | Function delegation subnet | Kafka subnet | 9093 | TCP |
| Outbound | Function delegation subnet | Kafka subnet | 9094 | TCP (replication, if needed) |
| Inbound (Kafka subnet) | Function delegation subnet | Kafka subnet | 9093 | TCP |

---

## 4-View Dashboard Architecture

### View 1 — Cluster Overview

**Purpose:** High-level health snapshot of the Kafka cluster.

**Data:** Broker count, partition counts, replication status, under-replicated partitions, offline partitions.

**Components:**

| Component | Type | Notes |
|---|---|---|
| `ClusterOverviewPage` | Server Component | Fetches broker metadata at SSR time |
| `BrokerCard` | Server Component | Renders per-broker status |
| `HealthBadge` | Client Component | Colour-coded status badge |
| `AutoRefresh` | Client Component | Polls `/api/cluster/overview` every 30 s via `setInterval` |

**API route:** `GET /api/cluster/overview`

```typescript
// Returns: { brokers: BrokerInfo[], topics: number, partitions: number,
//            underReplicated: number, offlinePartitions: number }
```

**Refresh strategy:** Initial render via Server Component SSR + client-side 30-second polling using `useSWR` with `refreshInterval`.

---

### View 2 — Topic Detail

**Purpose:** Drill into a specific topic's partition layout, leader distribution, and offset watermarks.

**Data:** Topic metadata (partitions, replicas, ISR), begin/end offsets per partition, topic configuration.

**Components:**

| Component | Type | Notes |
|---|---|---|
| `TopicListPage` | Server Component | Lists all topics, links to detail |
| `TopicDetailPage` | Server Component | Fetches full metadata for one topic |
| `PartitionTable` | Server Component | Renders partition/offset/leader table |
| `ConfigPanel` | Client Component | Expandable config accordion |

**API routes:**

- `GET /api/topics` — list all topics with partition count
- `GET /api/topics/[name]` — full detail: metadata, offsets, configs
- `PUT /api/topics/[name]/config` — update topic config (admin operation)

**Refresh strategy:** On-demand refresh button (Server Action or router refresh).

---

### View 3 — Consumer Groups

**Purpose:** Monitor consumer group health and per-partition lag.

**Data:** All consumer groups, per-group state (Stable/Rebalancing/Empty), member assignment, committed vs. end offsets, lag per partition.

**Components:**

| Component | Type | Notes |
|---|---|---|
| `ConsumerGroupsPage` | Server Component | Lists groups with aggregate lag |
| `GroupDetailPage` | Server Component | Renders member table + partition lag |
| `LagChart` | Client Component | Bar chart (e.g., Recharts) showing lag per partition |
| `GroupStateIndicator` | Client Component | Live state badge; re-fetches every 15 s |

**API routes:**

- `GET /api/consumer-groups` — all groups with state and total lag
- `GET /api/consumer-groups/[groupId]` — full description + lag breakdown
- `GET /api/consumer-groups/[groupId]/lag` — lag per topic/partition

**Refresh strategy:** Auto-refresh every 15 seconds via `useSWR` for the lag chart and state badge.

---

### View 4 — Message Browser

**Purpose:** Inspect messages in a topic and produce test messages.

**Data:** Last N messages from a topic partition (key, value, timestamp, headers), schema registry metadata if applicable.

**Components:**

| Component | Type | Notes |
|---|---|---|
| `MessageBrowserPage` | Server Component | Initial render with empty state |
| `MessageFetcher` | Client Component | Controls topic/partition selection, triggers fetch |
| `MessageTable` | Client Component | Displays messages with expand/collapse |
| `ProduceForm` | Client Component | Form for producing a test message |
| `StreamingConsumer` | Client Component | EventSource to `/api/messages/stream` for live tail |

**API routes:**

- `GET /api/messages/consume?topic=X&limit=N` — fetch last N messages
- `POST /api/messages/produce` — produce a message `{ topic, key, value, headers }`
- `GET /api/messages/stream?topic=X` — SSE stream for live message tail

**Refresh strategy:** User-initiated fetch for historical messages; SSE stream for live tail. Streaming uses the Web `ReadableStream` API in the Route Handler.

---

## Static Assets and CDN

### Next.js Static Optimisation

Next.js 15 with `output: 'standalone'` generates:

- **Static HTML** for pages with no dynamic data (pre-rendered at build time)
- **`_next/static/`** — hashed JS chunks, CSS, fonts (long-lived cache)
- **`public/`** — user-supplied assets (images, icons, manifests)

Set `assetPrefix` in `next.config.ts` to point to the CDN origin:

```typescript
const nextConfig: NextConfig = {
  output: 'standalone',
  assetPrefix: process.env.CDN_ORIGIN ?? '',
};
```

### Azure Front Door

Azure Front Door serves as both the public HTTPS ingress and CDN layer:

| Rule | Behaviour |
|---|---|
| `/_next/static/**` | Cache with `Cache-Control: public, max-age=31536000, immutable` |
| `/public/**` | Cache with `Cache-Control: public, max-age=86400` |
| `/**` (SSR routes) | No cache, forward to Function App origin |

TLS termination happens at Front Door using a Let's Encrypt certificate stored in Azure Key Vault. The Function App origin accepts only private traffic from the Front Door-managed IP range (enforced via access restrictions).

### Image Optimisation

Use Next.js `<Image>` component with a custom `loader` pointing to the CDN. Disable the built-in image optimisation server if images are served entirely from CDN:

```typescript
// next.config.ts
images: {
  loader: 'custom',
  loaderFile: './lib/cdn-loader.ts',
},
```

---

## Example Project Structure

```
kafka-lab-ui/
├── app/
│   ├── layout.tsx                     # Root layout
│   ├── dashboard/
│   │   ├── layout.tsx                 # Dashboard shell
│   │   ├── loading.tsx                # Suspense fallback
│   │   ├── error.tsx                  # Error boundary
│   │   └── (views)/
│   │       ├── overview/
│   │       │   └── page.tsx
│   │       ├── topics/
│   │       │   ├── page.tsx
│   │       │   └── [name]/
│   │       │       └── page.tsx
│   │       ├── consumer-groups/
│   │       │   ├── page.tsx
│   │       │   └── [groupId]/
│   │       │       └── page.tsx
│   │       └── messages/
│   │           └── page.tsx
│   └── api/
│       ├── cluster/
│       │   └── overview/route.ts
│       ├── topics/
│       │   ├── route.ts
│       │   └── [name]/route.ts
│       ├── consumer-groups/
│       │   ├── route.ts
│       │   └── [groupId]/
│       │       ├── route.ts
│       │       └── lag/route.ts
│       └── messages/
│           ├── consume/route.ts
│           ├── produce/route.ts
│           └── stream/route.ts
├── components/
│   ├── cluster/
│   ├── topics/
│   ├── consumer-groups/
│   └── messages/
├── lib/
│   └── kafka/
│       └── client.ts                  # Singleton Kafka client
├── public/
├── host.json                          # Azure Functions custom handler config
├── local.settings.json
├── next.config.ts
├── package.json
└── tsconfig.json
```

### Key File: `app/api/cluster/overview/route.ts`

```typescript
import { NextResponse } from 'next/server';
import { getKafkaClient } from '@/lib/kafka/client';

export const dynamic = 'force-dynamic';

export async function GET() {
  const admin = getKafkaClient().admin();
  await admin.connect();
  try {
    const metadata = await admin.fetchTopicMetadata();
    const brokers = metadata.brokers;
    const partitionCount = metadata.topics.reduce(
      (sum, t) => sum + t.partitions.length, 0
    );
    const underReplicated = metadata.topics.flatMap((t) =>
      t.partitions.filter((p) => p.isr.length < p.replicas.length)
    ).length;

    return NextResponse.json({
      brokers: brokers.map((b) => ({ id: b.nodeId, host: b.host, port: b.port })),
      topics: metadata.topics.length,
      partitions: partitionCount,
      underReplicated,
      offlinePartitions: metadata.topics.flatMap((t) =>
        t.partitions.filter((p) => p.leader === -1)
      ).length,
    });
  } finally {
    await admin.disconnect();
  }
}
```

---

## References

| Source | URL |
|---|---|
| Next.js 15 App Router docs | <https://nextjs.org/docs/app> |
| Next.js Route Handlers | <https://nextjs.org/docs/app/building-your-application/routing/route-handlers> |
| Next.js output: standalone | <https://nextjs.org/docs/app/api-reference/next-config-js/output> |
| confluent-kafka-javascript GitHub | <https://github.com/confluentinc/confluent-kafka-javascript> |
| confluent-kafka-javascript docs | <https://docs.confluent.io/kafka-clients/javascript/current/overview.html> |
| Admin Client API (KafkaJS) | <https://docs.confluent.io/platform/current/clients/confluent-kafka-javascript/docs/KafkaJS.Admin.html> |
| TypeScript Kafka examples | <https://github.com/confluentinc/confluent-kafka-javascript/blob/master/examples/typescript/kafkajs.ts> |
| Azure Functions networking options | <https://learn.microsoft.com/en-us/azure/azure-functions/functions-networking-options> |
| Azure Functions VNet private endpoints | <https://learn.microsoft.com/en-us/azure/azure-functions/functions-create-vnet> |
| Azure Functions custom handlers | <https://learn.microsoft.com/en-us/azure/azure-functions/functions-custom-handlers> |
| Azure Functions Node.js reference | <https://learn.microsoft.com/en-us/azure/azure-functions/functions-reference-node> |
| Kafka + Azure Functions closed network | <https://techcommunity.microsoft.com/blog/appsonazureblog/collaborate-kafka-and-azure-functions-securely-within-closed-network/2429394> |
| Azure Functions VNet quickstart template | <https://learn.microsoft.com/en-us/samples/azure/azure-quickstart-templates/function-app-vnet-integration/> |
| Next.js 15 Server vs Client Components | <https://drcodes.com/posts/nextjs-15-server-vs-client-components-complete-guide> |
| Next.js on Azure Functions (Altudo) | <https://www.altudo.co/insights/blogs/nextjs-on-azure-functions-serverless-architecture-for-faster-web-development> |
