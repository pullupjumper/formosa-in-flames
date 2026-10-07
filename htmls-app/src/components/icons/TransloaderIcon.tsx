import type { SVGProps } from 'react';

export function TransloaderIcon(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={256}
      height={256}
      viewBox="36 36 128 128"
      {...props}
    >
      <circle
        cx="100"
        cy="100"
        r="60"
        strokeWidth="4"
        stroke="black"
        fill="rgb(128,224,255)"
        fillOpacity="1"
      />
      <g transform="translate(0,0)">
        <g transform="scale(1)">
          <path
            d="m 60,120 80,0 M 120,80 c 25,0.2 25,40 0,40 l -40,0 C 55,120 55,80 80,80 Z"
            strokeWidth="3"
            stroke="black"
            fill="none"
          />
          <circle cx="80" cy="130" r="7" strokeWidth="3" stroke="black" fill="none" />
          <circle cx="120" cy="130" r="7" strokeWidth="3" stroke="black" fill="none" />
          <text
            x="100"
            y="100"
            textAnchor="middle"
            fontSize="30"
            fontFamily="Arial"
            fontWeight="bold"
            dominantBaseline="middle"
            strokeWidth="3"
            stroke="none"
            fill="black"
          >
            MSL
          </text>
          <path
            d="m 75,70 50,0 m -25,10 c 0,-5 0,-10 0,-10"
            strokeWidth="3"
            stroke="black"
            fill="none"
          />
        </g>
      </g>
    </svg>
  );
}
