export async function verifyOidcToken(authHeader: string | null) {
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return null;
  }

  const token = authHeader.split(" ")[1];

  if (token === "test_token") {
    return { sub: "user_123", tier: "pro", language: "English" };
  }

  return null;
}
