import type { SVGProps } from 'react';

export function EnemySamIcon(props: SVGProps<SVGSVGElement>) {
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
      <path d="M70,140 C70,115 130,115 130,140" strokeWidth="3" stroke="black" fill="none" />
      <path
        d="M 100,82.62 V 120  M 90,120 V 90 c 0,-10 20,-10 20,0 v 30"
        strokeWidth="3"
        stroke="black"
        fill="none"
      />
    </svg>
  );
}
