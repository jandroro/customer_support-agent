"use client";

import { useEffect, useRef } from "react";

import { Conversation } from "@/lib/types";
import { Avatar } from "./Avatar";
import { ChatInput } from "./ChatInput";
import { MessageBubble } from "./MessageBubble";
import { TypingIndicator } from "./TypingIndicator";

interface ChatWindowProps {
  conversation: Conversation | null;
  isLoading: boolean;
  error: string | null;
  onSend: (message: string) => void;
}

export function ChatWindow({ conversation, isLoading, error, onSend }: ChatWindowProps) {
  const bottomRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    bottomRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [conversation?.messages.length, isLoading]);

  const hasMessages = !!conversation && conversation.messages.length > 0;

  return (
    <main className="flex h-full min-w-0 flex-1 flex-col bg-gray-50">
      <header className="flex shrink-0 items-center gap-3 border-b border-gray-200 bg-white px-6 py-4">
        <Avatar variant="assistant" />
        <div>
          <h1 className="text-sm font-semibold text-gray-900">
            {conversation?.title ?? "TechCorp Customer Support"}
          </h1>
          <p className="flex items-center gap-1.5 text-xs text-gray-500">
            <span className="h-1.5 w-1.5 rounded-full bg-emerald-500" />
            Powered by Amazon Bedrock AgentCore
          </p>
        </div>
      </header>

      <div className="flex-1 overflow-y-auto">
        <div className="mx-auto flex w-full max-w-4xl flex-col gap-5 px-6 py-6">
          {!hasMessages ? (
            <div className="flex flex-col items-center justify-center gap-3 py-24 text-center">
              <Avatar variant="assistant" />
              <p className="max-w-sm text-sm text-gray-500">
                Ask about product info, warranty status, return policies, or
                technical support.
              </p>
            </div>
          ) : (
            conversation!.messages.map((message) => (
              <MessageBubble key={message.id} message={message} />
            ))
          )}
          {isLoading && <TypingIndicator />}
          {error && (
            <div className="rounded-lg border border-red-200 bg-red-50 px-4 py-2 text-sm text-red-700">
              {error}
            </div>
          )}
          <div ref={bottomRef} />
        </div>
      </div>

      <div className="mx-auto w-full max-w-4xl px-6 pb-6">
        <ChatInput onSend={onSend} disabled={isLoading} />
      </div>
    </main>
  );
}
