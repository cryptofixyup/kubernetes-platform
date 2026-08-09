import Stripe from "stripe";
import { Queue } from "bullmq";
import Redis from "ioredis";
import { verifyOidcToken } from "./middleware/fastOidcAuth";
import { checkRateLimit } from "./middleware/inMemoryRateLimiter";

const redisConnection = new Redis(process.env.REDIS_URL || "redis://localhost:6379");
const stripeQueue = new Queue("stripe-webhooks", { connection: redisConnection });
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || "sk_test_mock", {
  apiVersion: "2024-06-20",
  typescript: true,
});
const endpointSecret = process.env.STRIPE_WEBHOOK_SECRET || "whsec_mock";
const pythonAiBackend = process.env.PYTHON_BACKEND_URL || "http://localhost:8000";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

const server = Bun.serve({
  port: Number(process.env.PORT || 3000),

  async fetch(req) {
    const url = new URL(req.url);

    if (req.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders });
    }

    if (url.pathname === "/api/webhooks/stripe" && req.method === "POST") {
      const signature = req.headers.get("stripe-signature");
      const payload = await req.text();
      let event: Stripe.Event;

      try {
        event = stripe.webhooks.constructEvent(payload, signature || "", endpointSecret);
      } catch {
        return new Response("Invalid Signature", { status: 400, headers: corsHeaders });
      }

      try {
        await stripeQueue.add(event.type, event, {
          jobId: event.id,
          attempts: 8,
          backoff: { type: "exponential", delay: 5000 },
          removeOnComplete: { age: 24 * 3600 },
          removeOnFail: { age: 7 * 24 * 3600 },
        });

        return new Response("Queued", { status: 200, headers: corsHeaders });
      } catch {
        return new Response("Service Unavailable", { status: 503, headers: corsHeaders });
      }
    }

    const authHeader = req.headers.get("Authorization");
    const tenant = await verifyOidcToken(authHeader);

    if (!tenant) {
      return new Response("Unauthorized", { status: 401, headers: corsHeaders });
    }

    const withinLimit = await checkRateLimit(tenant.sub, tenant.tier);

    if (!withinLimit) {
      return new Response("Rate Limit Exceeded", { status: 429, headers: corsHeaders });
    }

    if (url.pathname.startsWith("/api/v1/chat")) {
      try {
        const requestBody = req.method !== "GET" ? await req.text() : undefined;
        const pythonResponse = await fetch(`${pythonAiBackend}${url.pathname}${url.search}`, {
          method: req.method,
          headers: {
            "Content-Type": req.headers.get("Content-Type") || "application/json",
            "X-User-Id": tenant.sub,
            "X-User-Tier": tenant.tier,
            "X-User-Lang": tenant.language || "English",
          },
          body: requestBody,
        });

        const responseHeaders = new Headers(pythonResponse.headers);

        Object.entries(corsHeaders).forEach(([key, value]) => responseHeaders.set(key, value));

        return new Response(pythonResponse.body, {
          status: pythonResponse.status,
          headers: responseHeaders,
        });
      } catch {
        return new Response("AI Engine Offline", { status: 503, headers: corsHeaders });
      }
    }

    return new Response("Not Found", { status: 404, headers: corsHeaders });
  },
});

console.log(`🛡️ Bun Gateway Active at: ${server.url}`);
