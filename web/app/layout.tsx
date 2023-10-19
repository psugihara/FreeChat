import type { Metadata } from "next";
import { Inter } from "next/font/google";
import "./globals.css";

const inter = Inter({ subsets: ["latin"] });

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
      <body className={inter.className}>
        {children}
        <footer className="flex flex-col items-center text-center text-white dark:bg-black text-neutral-800 dark:text-neutral-400">
          <div className="w-full p-4 text-center">
            © 2023{" "}
            <a
              href="https://x.com/_0_"
              target="_blank"
              rel="noopener noreferrer"
            >
              Peter Sugihara
            </a>
          </div>
        </footer>
      </body>
    </html>
  );
}
