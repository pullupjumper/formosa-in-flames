import type { SVGProps } from 'react';

export function RadarIcon(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={316}
      height={216}
      viewBox="21 46 158 108"
      {...props}
    >
      <path
        d="M25,50 l150,0 0,100 -150,0 z"
        strokeWidth="4"
        stroke="black"
        fill="rgb(128,224,255)"
        fillOpacity="1"
      />
      <path
        d="M 108,117 C 86,129 65,93 86.7,80.7 Z  M 97.2,99.1 118,88.7"
        strokeWidth="3"
        stroke="black"
        fill="rgb(239, 239, 239)"
      />
    </svg>
  );
}
