import { ChatMessage } from "@/lib/types";
import { Avatar } from "./Avatar";

export function MessageBubble({ message }: { message: ChatMessage }) {
  const isUser = message.role === "user";

  return (
    <div className={`flex items-start gap-3 ${isUser ? "flex-row-reverse" : ""}`}>
      <Avatar variant={message.role} />
      <div
        className={`max-w-[70%] whitespace-pre-wrap rounded-2xl px-4 py-2.5 text-sm leading-relaxed shadow-sm ${
          isUser
            ? "rounded-tr-sm bg-violet-600 text-white"
            : "rounded-tl-sm border border-gray-200 bg-white text-gray-900"
        }`}
      >
        {message.content}
      </div>
    </div>
  );
}
