"use client";

import { useEffect, useState } from "react";

import { AuthForm } from "@/components/AuthForm";
import { ChatApp } from "@/components/ChatApp";
import { AuthSession, clearSession, loadSession, saveSession } from "@/lib/auth";

export default function Home() {
  const [session, setSession] = useState<AuthSession | null>(null);
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    setSession(loadSession());
    setHydrated(true);
  }, []);

  if (!hydrated) return null;

  if (!session) {
    return (
      <AuthForm
        onAuthenticated={(s) => {
          saveSession(s);
          setSession(s);
        }}
      />
    );
  }

  return (
    <ChatApp
      session={session}
      onSessionChange={(s) => {
        saveSession(s);
        setSession(s);
      }}
      onLogout={() => {
        clearSession();
        setSession(null);
      }}
    />
  );
}
