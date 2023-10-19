"use client";

import Tilt from "react-parallax-tilt";
import Image from "next/image";

export default function TiltyApp() {
  return (
    <Tilt glareEnable={true} glareMaxOpacity={0.45}>
      <Image
        src="/tidles-1024.png"
        alt="FreeChat app icon"
        width={256}
        height={256}
        priority
        className="transition-translate duration-300 group-hover:-translate-y-2 group-hover:translate-x-2 group-active:translate-x-0 group-active:translate-y-0 group-active:skew-y-0 transform-gpu skew-y-0 hover:skew-y-2 transition-transform motion-reduce:transform-none"
      />
      <Image
        src="/tidles-1024.png"
        alt="FreeChat app icon"
        width={256}
        height={256}
        priority
        className="absolute top-0 left-0 opacity-0 group-active:opacity-0 transition-opacity group-hover:opacity-50 invert dark:invert-0 z-[-1] duration-500"
      />
    </Tilt>
  );
}
