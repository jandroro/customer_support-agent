const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";

export interface ChatApiResponse {
  response: string;
  session_id: string;
  actor_id: string;
}

export async function sendMessage(
  message: string,
  sessionId: string,
  auth?: { accessToken: string; username: string },
): Promise<ChatApiResponse> {
  const res = await fetch(`${API_BASE_URL}/api/chat`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      message,
      session_id: sessionId,
      ...(auth ? { access_token: auth.accessToken, actor_id: auth.username } : {}),
    }),
  });

  if (!res.ok) {
    const detail = await res.text();
    throw new Error(`Request failed (${res.status}): ${detail}`);
  }

  return res.json();
}
