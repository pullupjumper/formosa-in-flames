import type { SVGProps } from 'react';

export function EnemyCommandAndControlIcon(props: SVGProps<SVGSVGElement>) {
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
      <text
        x="100"
        y="103"
        textAnchor="middle"
        fontSize="45"
        fontFamily="Arial"
        fontWeight="bold"
        dominantBaseline="middle"
        strokeWidth="3"
        stroke="none"
        fill="black"
      />
    </svg>
  );
}
