import type { SVGProps } from 'react';

export function ArmoredMechanizedTrackedIcon(props: SVGProps<SVGSVGElement>) {
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
      <path
        d="M125,80 C150,80 150,120 125,120 L75,120 C50,120 50,80 75,80 Z"
        strokeWidth="3"
        stroke="black"
        fill="none"
      />
      <path d="M60,70L140,130M60,130L140,70" strokeWidth="3" stroke="black" fill="black" />
      <path
        d="M 70.4 142.4 C 74.8 137 66.8 125 81.4 125 C 100.2 125 81.4 145 100.2 145 C 119 145 100.2 125 119 125 C 133.3 125 125.7 136.6 129.7 142.1 "
        strokeWidth="3"
        stroke="black"
        fill="none"
      />
    </svg>
  );
}
