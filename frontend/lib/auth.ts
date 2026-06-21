const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_BASE_URL ?? "http://localhost:8000";

const STORAGE_KEY = "customer-support-auth";

export interface AuthSession {
  accessToken: string;
  idToken: string;
  refreshToken: string;
  username: string;
}

interface AuthApiResponse {
  access_token: string;
  id_token: string;
  refresh_token: string;
  username: string;
}

function toSession(data: AuthApiResponse): AuthSession {
  return {
    accessToken: data.access_token,
    idToken: data.id_token,
    refreshToken: data.refresh_token,
    username: data.username,
  };
}

async function postAuth(path: string, body: Record<string, unknown>): Promise<AuthSession> {
  const res = await fetch(`${API_BASE_URL}${path}`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });

  if (!res.ok) {
    const detail = await res.text();
    throw new Error(detail || `Request failed (${res.status})`);
  }

  return toSession(await res.json());
}

export function login(username: string, password: string): Promise<AuthSession> {
  return postAuth("/api/auth/login", { username, password });
}

export function register(username: string, password: string, email?: string): Promise<AuthSession> {
  return postAuth("/api/auth/register", { username, password, email });
}

export function refreshSession(session: AuthSession): Promise<AuthSession> {
  return postAuth("/api/auth/refresh", {
    username: session.username,
    refresh_token: session.refreshToken,
  });
}

export function saveSession(session: AuthSession): void {
  sessionStorage.setItem(STORAGE_KEY, JSON.stringify(session));
}

export function loadSession(): AuthSession | null {
  const raw = sessionStorage.getItem(STORAGE_KEY);
  if (!raw) return null;
  try {
    return JSON.parse(raw) as AuthSession;
  } catch {
    return null;
  }
}

export function clearSession(): void {
  sessionStorage.removeItem(STORAGE_KEY);
}

// Decodes the JWT payload client-side (no signature verification — only used
// to proactively refresh before expiry, the Runtime/Gateway authorizers are
// what actually verify the token) to read its "exp" claim.
export function isTokenExpiringSoon(accessToken: string): boolean {
  try {
    const payload = JSON.parse(atob(accessToken.split(".")[1]));
    const expiresAtMs = payload.exp * 1000;
    return Date.now() > expiresAtMs - 60_000;
  } catch {
    return true;
  }
}
