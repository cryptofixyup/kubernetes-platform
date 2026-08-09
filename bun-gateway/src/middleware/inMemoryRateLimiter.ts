export async function checkRateLimit(userId: string, tier: string): Promise<boolean> {
  void userId;

  if (tier === "enterprise") {
    return true;
  }

  return true;
}
