import Image from "next/image";
import TiltyApp from "./TiltyApp";

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24 text-center">
      <div className="flex flex-col place-items-center relative">
        <h1 className="text-6xl font-black before:absolute before:h-[300px] before:w-[500px] before:rounded-full before:bg-gradient-radial before:from-white before:to-transparent before:blur-2xl before:content-[''] after:absolute after:-z-20 after:h-[180px] after:w-[340px] after:-translate-x-1/3 before:dark:bg-gradient-to-br before:dark:from-transparent before:dark:to-violet-700 before:dark:opacity-10 after:dark:from-white after:dark:via-[#0141ff] after:dark:opacity-40 before:lg:h-[360px] z-10">
          FreeChat
        </h1>
        <h2 className="text-2xl block pt-3 z-50">
          Local, secure, open-source AI chat for macOS
        </h2>
        <a
          className="z-50 group duration-300 ease-in-out"
          href="https://6032904148827.gumroad.com/l/freechat-beta?_gl=1*1qow0km*_ga*MjEwOTUwNzk3MC4xNjk1MjMyNjEz*_ga_6LJN6D94N6*MTY5NzY5MzA5MS4xNC4xLjE2OTc2OTMwOTQuMC4wLjA."
          target="_blank"
          rel="noopener noreferrer"
        >
          <div className="relative my-2">
            <TiltyApp />
          </div>

          <h2 className="mb-3 text-2xl font-semibold">
            Download it{" "}
            <span className="inline-block transition-transform group-hover:translate-x-1 motion-reduce:transform-none">
              -&gt;
            </span>
          </h2>
        </a>
      </div>
    </main>
  );
}
