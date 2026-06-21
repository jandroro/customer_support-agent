import { Conversation } from "./types";

const STORAGE_PREFIX = "customer-support-conversations";

function storageKey(username: string): string {
  return `${STORAGE_PREFIX}:${username}`;
}

export function loadConversations(username: string): Conversation[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(storageKey(username));
    if (!raw) return [];
    const parsed = JSON.parse(raw) as Conversation[];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

export function saveConversations(username: string, conversations: Conversation[]): void {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(storageKey(username), JSON.stringify(conversations));
}

export function deriveTitle(message: string): string {
  const trimmed = message.trim().replace(/\s+/g, " ");
  if (trimmed.length <= 42) return trimmed;
  return `${trimmed.slice(0, 42)}…`;
}
