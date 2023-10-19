"use client";

import Tilt from "react-parallax-tilt";
import Image from "next/image";

export default function TiltyApp() {
  return (
    <Tilt
      className="group"
      tiltMaxAngleX={40}
      tiltMaxAngleY={20}
      perspective={2000}
      transitionSpeed={1500}
      scale={1.05}
      tiltReverse={true}
    >
      <Image
        src="/tidles-1024.png"
        alt="FreeChat app icon"
        width={256}
        height={256}
        priority
        className="transition-translate duration-300 translate-z-96 group-hover:-translate-y-2 group-hover:translate-x-2 group-active:translate-x-0 group-active:translate-y-0 transform-gpu transition-transform motion-reduce:transform-none"
      />
      <Image
        src="/tidles-1024.png"
        alt="FreeChat app icon"
        width={256}
        height={256}
        priority
        className="absolute top-0 left-0 opacity-0 -translate-z-96 group-active:opacity-0 transition-opacity group-hover:opacity-50 invert dark:invert-0 z-[-1] duration-500"
      />
    </Tilt>
  );
}
