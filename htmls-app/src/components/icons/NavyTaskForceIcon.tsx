import type { SVGProps } from 'react';

export function NavyTaskForceIcon(props: SVGProps<SVGSVGElement>) {
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
        d="m 110,80 15,15 0,25 M 90,80 75,95 l 0,25"
        strokeWidth="3"
        stroke="black"
        fill="none"
      />
      <text
        x="100"
        y="110"
        textAnchor="middle"
        fontSize="30"
        fontFamily="Arial"
        fontWeight="bold"
        dominantBaseline="middle"
        strokeWidth="3"
        stroke="none"
        fill="black"
      >
        TF
      </text>
    </svg>
  );
}
