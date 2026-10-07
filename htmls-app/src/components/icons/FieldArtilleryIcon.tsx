import type { SVGProps } from 'react';

export function FieldArtilleryIcon(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={304}
      height={304}
      viewBox="24 24 152 152"
      {...props}
    >
      <path
        d="M 100,28 L172,100 100,172 28,100 100,28 Z"
        strokeWidth="4"
        stroke="black"
        fill="rgb(255,128,128)"
        fillOpacity="1"
      />
      <circle cx="100" cy="100" r="15" strokeWidth="3" stroke="black" fill="black" />
      <path
        d="m 90,60 20,0 c 10,0 10,15 0,15 L 90,75 C 80,75 80,60 90,60"
        strokeWidth="3"
        stroke="black"
        fill="none"
      />
      <circle cx="75" cy="130" r="7" strokeWidth="3" stroke="black" fill="none" />
      <circle cx="100" cy="130" r="7" strokeWidth="3" stroke="black" fill="none" />
      <circle cx="125" cy="130" r="7" strokeWidth="3" stroke="black" fill="none" />
    </svg>
  );
}
