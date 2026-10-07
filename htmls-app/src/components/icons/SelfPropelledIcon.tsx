import type { SVGProps } from 'react';

export function SelfPropelledIcon(props: SVGProps<SVGSVGElement>) {
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
      <g transform="translate(20,20)">
        <g transform="scale(0.8)">
          <circle cx="100" cy="100" r="15" strokeWidth="3" stroke="black" fill="black" />
        </g>
      </g>
      <path
        d="M125,80 C150,80 150,120 125,120 L75,120 C50,120 50,80 75,80 Z"
        strokeWidth="3"
        stroke="black"
        fill="none"
      />
    </svg>
  );
}
