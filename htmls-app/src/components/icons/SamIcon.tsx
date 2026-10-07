import type { SVGProps } from 'react';

export function SamIcon(props: SVGProps<SVGSVGElement>) {
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
      <path d="M25,150 C25,110 175,110 175,150" strokeWidth="3" stroke="black" fill="none" />
      <path
        d="M 100,82.62 V 120  M 90,120 V 90 c 0,-10 20,-10 20,0 v 30"
        strokeWidth="3"
        stroke="black"
        fill="none"
      />
    </svg>
  );
}
