"use client";

import { useEffect, useState } from "react";
import { v4 as uuidv4 } from "uuid";

import { sendMessage } from "@/lib/api";
import { AuthSession, isTokenExpiringSoon, refreshSession } from "@/lib/auth";
import { deriveTitle, loadConversations, saveConversations } from "@/lib/conversations";
import { ChatMessage, Conversation } from "@/lib/types";
import { ChatWindow } from "./ChatWindow";
import { Sidebar } from "./Sidebar";

function createConversation(): Conversation {
  return {
    id: uuidv4(),
    title: "New conversation",
    messages: [],
    updatedAt: Date.now(),
  };
}

interface ChatAppProps {
  session: AuthSession;
  onSessionChange: (session: AuthSession) => void;
  onLogout: () => void;
}

export function ChatApp({ session, onSessionChange, onLogout }: ChatAppProps) {
  const [conversations, setConversations] = useState<Conversation[]>([]);
  const [activeId, setActiveId] = useState<string | null>(null);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [hydrated, setHydrated] = useState(false);

  // Load persisted conversations once on mount, scoped to the logged-in user.
  useEffect(() => {
    const stored = loadConversations(session.username);
    setConversations(stored);
    if (stored.length > 0) setActiveId(stored[0].id);
    setHydrated(true);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [session.username]);

  // Persist on every change, but only after the initial load completes
  // (otherwise this would overwrite localStorage with an empty array first).
  useEffect(() => {
    if (hydrated) saveConversations(session.username, conversations);
  }, [conversations, hydrated, session.username]);

  const activeConversation = conversations.find((c) => c.id === activeId) ?? null;

  const handleNewConversation = () => {
    const conversation = createConversation();
    setConversations((prev) => [conversation, ...prev]);
    setActiveId(conversation.id);
    setError(null);
  };

  const handleDeleteConversation = (id: string) => {
    setConversations((prev) => prev.filter((c) => c.id !== id));
    setActiveId((current) => (current === id ? null : current));
  };

  const handleSend = async (text: string) => {
    let conversation = activeConversation;
    if (!conversation) {
      conversation = createConversation();
      setConversations((prev) => [conversation as Conversation, ...prev]);
      setActiveId(conversation.id);
    }

    const conversationId = conversation.id;
    const isFirstMessage = conversation.messages.length === 0;
    const userMessage: ChatMessage = {
      id: uuidv4(),
      role: "user",
      content: text,
      createdAt: Date.now(),
    };

    setConversations((prev) =>
      prev.map((c) =>
        c.id === conversationId
          ? {
              ...c,
              title: isFirstMessage ? deriveTitle(text) : c.title,
              messages: [...c.messages, userMessage],
              updatedAt: Date.now(),
            }
          : c,
      ),
    );

    setIsLoading(true);
    setError(null);

    try {
      let activeSession = session;
      if (isTokenExpiringSoon(activeSession.accessToken)) {
        activeSession = await refreshSession(activeSession);
        onSessionChange(activeSession);
      }

      // The conversation id doubles as the AgentCore session id, so memory
      // continuity is tied 1:1 to a sidebar entry — no separate id to track.
      const data = await sendMessage(text, conversationId, {
        accessToken: activeSession.accessToken,
        username: activeSession.username,
      });
      const assistantMessage: ChatMessage = {
        id: uuidv4(),
        role: "assistant",
        content: data.response,
        createdAt: Date.now(),
      };
      setConversations((prev) =>
        prev.map((c) =>
          c.id === conversationId
            ? { ...c, messages: [...c.messages, assistantMessage], updatedAt: Date.now() }
            : c,
        ),
      );
    } catch (err) {
      setError(err instanceof Error ? err.message : "Something went wrong.");
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="flex h-screen w-screen overflow-hidden bg-gray-50">
      <Sidebar
        conversations={conversations}
        activeId={activeId}
        onSelect={(id) => {
          setActiveId(id);
          setError(null);
        }}
        onNew={handleNewConversation}
        onDelete={handleDeleteConversation}
        username={session.username}
        onLogout={onLogout}
      />
      <ChatWindow
        conversation={activeConversation}
        isLoading={isLoading}
        error={error}
        onSend={handleSend}
      />
    </div>
  );
}
