import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

// const bodyFont = IBM_Plex_Mono({ subsets: ["latin"], weight: "500" });
const bodyFont = Inter({ subsets: ["latin"] });

export const metadata: Metadata = {
  title: "FreeChat",
  description: "Local, secure, open-source AI chat for macOS",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body className={bodyFont.className}>
        {children}
        <footer className="w-full m-auto">
          <div className="flex max-w-xs flex-col sm:flex-row justify-between dark:bg-black p-4 space-y-2 sm:space-y-0 sm:max-w-xl m-auto">
            <a
              href="https://github.com/psugihara/FreeChat"
              target="_blank"
              rel="noopener noreferrer"
            >
              Github
            </a>
            <a href="/legal/privacy">Privacy</a>
            <a href="/legal/terms">Terms</a>
            <div className="whitespace-nowrap">
              <a
                href="https://x.com/_0_"
                target="_blank"
                rel="noopener noreferrer"
              >
                © 2023 Peter Sugihara
              </a>
            </div>
          </div>
        </footer>
      </body>
    </html>
  );
}
