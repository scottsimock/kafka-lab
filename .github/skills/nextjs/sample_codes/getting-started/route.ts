// API Route Handler: Health check endpoint
// Defined in app/api/health/route.ts

import { NextResponse } from "next/server";

export async function GET() {
  const health = {
    status: "healthy",
    timestamp: new Date().toISOString(),
    version: process.env.npm_package_version ?? "unknown",
  };

  return NextResponse.json(health, { status: 200 });
}
