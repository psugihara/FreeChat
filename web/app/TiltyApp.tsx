"use client";

import Tilt from "react-parallax-tilt";
import Image from "next/image";
import { useEffect } from "react";
import { emojiCursor } from "cursor-effects";

function activateCursor() {
  emojiCursor({ emoji: ["🔥", "🐬", "🦆"] });
}

export default function TiltyApp() {
  return (
    <div
      className="rounded-3xl transition-all group-hover:bg-gray-200 dark:group-hover:bg-gray-600"
      onMouseEnter={activateCursor}
    >
      <Tilt
        className="group"
        tiltMaxAngleX={20}
        tiltMaxAngleY={20}
        perspective={2000}
        transitionSpeed={1500}
        scale={1.04}
        tiltReverse={true}
      >
        <Image
          src="/tidles-1024.png"
          alt="FreeChat app icon"
          width={128}
          height={128}
          priority
          className="bg-white shadow-icon rounded-3xl transition-all duration-300 translate-z-96 group-hover:-translate-y-3 group-hover:translate-x-3 group-hover:skew-y-6 group-active:translate-x-0 group-active:translate-y-0 transform-gpu motion-reduce:transform-none"
        />
      </Tilt>
    </div>
  );
}
