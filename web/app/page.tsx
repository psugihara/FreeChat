import Image from "next/image";
import TiltyApp from "./TiltyApp";

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24">
      <div className="flex flex-col relative">
        <Image
          src="/tidles-1024.png"
          alt="FreeChat app icon"
          width={64}
          height={64}
          priority
          className="mb-16 bg-white sm:hidden shadow-icon rounded-3xl transition-all duration-300 translate-z-96 group-hover:-translate-y-3 group-hover:translate-x-3 group-hover:skew-y-6 group-active:translate-x-0 group-active:translate-y-0 transform-gpu motion-reduce:transform-none"
        />
        <h1 className="text-6xl sm:text-9xl font-semibold">FreeChat</h1>
        <h2 className="text-2xl sm:text-5xl block pt-4 pb-6 sm:pb-12 max-w-[330px] sm:max-w-[660px] leading-tight sm:leading-tight">
          Local, secure, open source AI chat for macOS
        </h2>
        <a
          className="group duration-300 ease-in-out flex items-center justify-between"
          href="https://apps.apple.com/us/app/freechat/id6458534902"
          target="_blank"
          rel="noopener noreferrer"
        >
          <h2 className="mb-3 text-3xl sm:text-6xl font-semibold light:text-slate-800 light:hover:text-black">
            Get it now{" "}
            <span className="inline-block transition-transform group-hover:translate-x-1 motion-reduce:transform-none">
              -&gt;
            </span>
          </h2>
          <div className="pb-4 pr-12 hidden sm:block">
            <TiltyApp />
          </div>
        </a>
      </div>
    </main>
  );
}
