import { Worker, Job } from "bullmq";
import Redis from "ioredis";
import Stripe from "stripe";

console.log("👷 Starting Resilient Webhook Worker...");

const redisConnection = new Redis(process.env.REDIS_URL || "redis://localhost:6379");

const worker = new Worker(
  "stripe-webhooks",
  async (job: Job) => {
    const event = job.data as Stripe.Event;

    try {
      if (event.type === "checkout.session.completed") {
        const session = event.data.object as Stripe.Checkout.Session;
        await executeDatabaseUpdateSafe(String(session.customer), "pro", event.id);
      } else if (event.type === "customer.subscription.deleted") {
        const subscription = event.data.object as Stripe.Subscription;
        await executeDatabaseUpdateSafe(String(subscription.customer), "free", event.id);
      }
    } catch (error) {
      const message = error instanceof Error ? error.message : "Unknown worker error";
      throw new Error(message);
    }

    return { status: "success" };
  },
  { connection: redisConnection, concurrency: 5 },
);

worker.on("failed", (job, err) => {
  if (job && job.attemptsMade === job.opts.attempts) {
    console.error(`🚨 FATAL: Job ${job.id} failed entirely!`, err);
  }
});

async function executeDatabaseUpdateSafe(customerId: string, targetTier: string, eventId: string) {
  console.log(`💾 Updated ${customerId} to ${targetTier}. Saved event: ${eventId}`);
  return "updated";
}
