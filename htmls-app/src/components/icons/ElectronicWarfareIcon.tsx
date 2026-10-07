import type { SVGProps } from 'react';

export function ElectronicWarfareIcon(props: SVGProps<SVGSVGElement>) {
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
      >
        EW
      </text>
    </svg>
  );
}
