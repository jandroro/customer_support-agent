import { BotIcon, UserIcon } from "./icons";

export function Avatar({ variant }: { variant: "user" | "assistant" }) {
  const isAssistant = variant === "assistant";

  return (
    <div
      className={`flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-white shadow-sm ${
        isAssistant
          ? "bg-gradient-to-br from-violet-500 to-indigo-600"
          : "bg-gradient-to-br from-gray-600 to-gray-800"
      }`}
    >
      {isAssistant ? <BotIcon className="h-4 w-4" /> : <UserIcon className="h-4 w-4" />}
    </div>
  );
}
