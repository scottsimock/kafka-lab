// API Route Handler: Manage Kafka topics
// Defined in app/api/topics/route.ts

import { NextRequest, NextResponse } from "next/server";

interface Topic {
  name: string;
  partitions: number;
  replicationFactor: number;
}

const KAFKA_API = process.env.KAFKA_API_URL ?? "http://localhost:8082";

export async function GET() {
  try {
    const res = await fetch(`${KAFKA_API}/topics`, {
      cache: "no-store",
      headers: { Accept: "application/json" },
    });

    if (!res.ok) {
      return NextResponse.json(
        { error: "Failed to fetch topics" },
        { status: res.status }
      );
    }

    const topics: Topic[] = await res.json();
    return NextResponse.json({ topics });
  } catch (error) {
    return NextResponse.json(
      { error: "Kafka API unreachable" },
      { status: 503 }
    );
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();

    if (!body.name) {
      return NextResponse.json(
        { error: "Topic name is required" },
        { status: 400 }
      );
    }

    const payload = {
      topic_name: body.name,
      partitions_count: body.partitions ?? 6,
      replication_factor: body.replicationFactor ?? 3,
      configs: body.configs ?? [],
    };

    const res = await fetch(`${KAFKA_API}/topics`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(payload),
    });

    if (!res.ok) {
      const errorBody = await res.text();
      return NextResponse.json(
        { error: `Failed to create topic: ${errorBody}` },
        { status: res.status }
      );
    }

    return NextResponse.json(
      { message: `Topic '${body.name}' created`, ...payload },
      { status: 201 }
    );
  } catch (error) {
    return NextResponse.json(
      { error: "Failed to create topic" },
      { status: 500 }
    );
  }
}
