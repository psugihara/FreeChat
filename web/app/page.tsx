import TiltyApp from "./TiltyApp";

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24">
      <div className="flex flex-col  relative">
        <div className="relative -ml-10">
          <TiltyApp />
        </div>
        <h1 className="text-9xl font-semibold">FreeChat</h1>
        <h2 className="text-5xl block pt-4 pb-12 z-50 max-w-[660px] leading-tight">
          Local, secure, open source AI chat for macOS
        </h2>
        {/* <a
          className="z-50 group duration-300 ease-in-out flex items-center justify-between"
          href="https://6032904148827.gumroad.com/l/freechat-beta?_gl=1*1qow0km*_ga*MjEwOTUwNzk3MC4xNjk1MjMyNjEz*_ga_6LJN6D94N6*MTY5NzY5MzA5MS4xNC4xLjE2OTc2OTMwOTQuMC4wLjA."
          target="_blank"
          rel="noopener noreferrer"
        >
          <h2 className="mb-3 text-6xl font-semibold text-slate-800 hover:text-black">
            Download it{" "}
            <span className="inline-block transition-transform group-hover:translate-x-1 motion-reduce:transform-none">
              -&gt;
            </span>
          </h2>
          <div className="relative pb-4 pr-12">
            <TiltyApp />
          </div>
        </a> */}
      </div>
    </main>
  );
}
