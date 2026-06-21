import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "TechCorp Customer Support",
  description: "Chat with the TechCorp customer support agent",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className="h-screen overflow-hidden bg-gray-50 text-gray-900 antialiased">
        {children}
      </body>
    </html>
  );
}
