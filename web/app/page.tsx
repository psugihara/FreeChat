import Image from 'next/image'

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-between p-24">
      <div className="z-10 max-w-5xl w-full items-center justify-between font-mono text-sm lg:flex">
      </div>

      <div className="relative flex flex-col place-items-center before:absolute before:h-[300px] before:w-[480px] before:-translate-x-1/2 before:rounded-full before:bg-gradient-radial before:from-white before:to-transparent before:blur-2xl before:content-[''] after:absolute after:-z-20 after:h-[180px] after:w-[240px] after:translate-x-1/3 after:bg-gradient-conic after:from-sky-200 after:via-blue-200 after:blur-2xl after:content-[''] before:dark:bg-gradient-to-br before:dark:from-transparent before:dark:to-blue-700 before:dark:opacity-10 after:dark:from-white after:dark:via-[#0141ff] after:dark:opacity-40 before:lg:h-[360px] z-[-1]">
        <h1 className="text-6xl font-black">FreeChat</h1>
        <h2 className="text-2xl block pt-3">Local, secure, open-source AI chat for macOS</h2>
        <Image
          src="/tidles-1024.png"
          alt="Next.js Logo"
          width={256}
          height={256}
          priority
        />
      </div>
      

      <div className="mb-32 text-center">
        <a
          href="https://6032904148827.gumroad.com/l/freechat-beta?_gl=1*1qow0km*_ga*MjEwOTUwNzk3MC4xNjk1MjMyNjEz*_ga_6LJN6D94N6*MTY5NzY5MzA5MS4xNC4xLjE2OTc2OTMwOTQuMC4wLjA."
          className="text-left group rounded-lg border border-transparent px-5 py-4 transition-colors hover:bg-gray-100 hover:dark:bg-neutral-800/30"
          target="_blank"
          rel="noopener noreferrer"
        >
          <h2 className="mb-3 text-2xl font-semibold">
            Download it{' '}
            <span className="inline-block transition-transform group-hover:translate-x-1 motion-reduce:transform-none">
              -&gt;
            </span>
          </h2>
        </a>
      </div>
    </main>
  )
}
