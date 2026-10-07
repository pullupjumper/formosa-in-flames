import type { SVGProps } from 'react';

export function CarrierIcon(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={304}
      height={304}
      viewBox="24 24 152 152"
      {...props}
    >
      <path
        d="M100,28 L172,100 100,172 28,100 100,28 Z"
        strokeWidth="4"
        stroke="black"
        fill="rgb(255,128,128)"
        fillOpacity="1"
      />
      <path
        d="m 80,100 20,20 20,-20 -20,0 0,-20 -20,0 z"
        strokeWidth="3"
        stroke="black"
        fill="black"
      />
    </svg>
  );
}
