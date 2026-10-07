import type { SVGProps } from 'react';

export function AmmunitionTransferPointIcon(props: SVGProps<SVGSVGElement>) {
  return (
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width={176}
      height={336}
      viewBox="56 -64 88 168"
      {...props}
    >
      <path
        d="m 60,45 80,0 m -40,55 -40,-55 0,-105 80,0 0,105 z"
        strokeWidth="3"
        stroke="black"
        fill="rgb(128,224,255)"
      />
      <text
        x="100"
        y="-30"
        textAnchor="middle"
        fontSize="35"
        fontFamily="Arial"
        fontWeight="bold"
        dominantBaseline="middle"
        strokeWidth="3"
        stroke="none"
        fill="black"
      >
        ATP
      </text>
    </svg>
  );
}
