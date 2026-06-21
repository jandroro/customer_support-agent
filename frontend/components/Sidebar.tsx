"use client";

import { useState } from "react";

import { Conversation } from "@/lib/types";
import { ConfirmDialog } from "./ConfirmDialog";
import { PlusIcon, TrashIcon } from "./icons";

interface SidebarProps {
  conversations: Conversation[];
  activeId: string | null;
  onSelect: (id: string) => void;
  onNew: () => void;
  onDelete: (id: string) => void;
  username: string;
  onLogout: () => void;
}

function formatTimestamp(ts: number): string {
  const date = new Date(ts);
  const now = new Date();
  const sameDay = date.toDateString() === now.toDateString();
  if (sameDay) {
    return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" });
  }
  return date.toLocaleDateString([], { month: "short", day: "numeric" });
}

export function Sidebar({
  conversations,
  activeId,
  onSelect,
  onNew,
  onDelete,
  username,
  onLogout,
}: SidebarProps) {
  const [pendingDelete, setPendingDelete] = useState<Conversation | null>(null);

  return (
    <aside className="flex h-full w-80 shrink-0 flex-col border-r border-gray-200 bg-white">
      <div className="flex items-center justify-between border-b border-gray-200 px-4 py-4">
        <h2 className="text-base font-semibold text-gray-900">Chats</h2>
        <button
          onClick={onNew}
          className="flex items-center gap-1.5 rounded-lg bg-violet-600 px-3 py-1.5 text-xs font-medium text-white transition hover:bg-violet-700"
        >
          <PlusIcon className="h-3.5 w-3.5" />
          New chat
        </button>
      </div>

      <div className="flex-1 overflow-y-auto">
        {conversations.length === 0 ? (
          <p className="px-4 py-6 text-center text-sm text-gray-400">
            No conversations yet — start one to see it here.
          </p>
        ) : (
          <ul className="divide-y divide-gray-100">
            {conversations.map((conversation) => {
              const lastMessage = conversation.messages[conversation.messages.length - 1];
              const isActive = conversation.id === activeId;
              return (
                <li key={conversation.id} className="group relative">
                  <button
                    onClick={() => onSelect(conversation.id)}
                    className={`flex w-full items-start gap-3 py-3 pl-4 pr-10 text-left transition ${
                      isActive ? "bg-violet-50" : "hover:bg-gray-50"
                    }`}
                  >
                    <div
                      className={`flex h-10 w-10 shrink-0 items-center justify-center rounded-full text-sm font-semibold text-white ${
                        isActive ? "bg-violet-600" : "bg-gray-400"
                      }`}
                    >
                      {conversation.title.charAt(0).toUpperCase()}
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center justify-between gap-2">
                        <p
                          className={`truncate text-sm font-medium ${
                            isActive ? "text-violet-900" : "text-gray-900"
                          }`}
                        >
                          {conversation.title}
                        </p>
                        <span className="shrink-0 text-[11px] text-gray-400">
                          {formatTimestamp(conversation.updatedAt)}
                        </span>
                      </div>
                      <p className="truncate text-xs text-gray-500">
                        {lastMessage ? lastMessage.content : "No messages yet"}
                      </p>
                    </div>
                  </button>
                  <button
                    onClick={(e) => {
                      e.stopPropagation();
                      setPendingDelete(conversation);
                    }}
                    aria-label="Delete conversation"
                    className="absolute right-2 top-1/2 -translate-y-1/2 rounded-md p-1.5 text-gray-400 opacity-0 transition hover:bg-gray-200 hover:text-red-600 group-hover:opacity-100"
                  >
                    <TrashIcon className="h-4 w-4" />
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </div>

      <ConfirmDialog
        open={pendingDelete !== null}
        title="Delete conversation?"
        description={pendingDelete ? `"${pendingDelete.title}" will be permanently removed.` : undefined}
        confirmLabel="Delete"
        onConfirm={() => {
          if (pendingDelete) onDelete(pendingDelete.id);
          setPendingDelete(null);
        }}
        onCancel={() => setPendingDelete(null)}
      />

      <div className="flex items-center justify-between border-t border-gray-200 px-4 py-3">
        <div className="flex min-w-0 items-center gap-2">
          <div className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-gray-700 text-xs font-semibold text-white">
            {username.charAt(0).toUpperCase()}
          </div>
          <p className="truncate text-sm font-medium text-gray-900">{username}</p>
        </div>
        <button
          onClick={onLogout}
          className="shrink-0 text-xs font-medium text-gray-500 hover:text-gray-900"
        >
          Log out
        </button>
      </div>
    </aside>
  );
}
