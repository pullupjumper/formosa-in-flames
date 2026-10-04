import type { ForceImage } from '@/types/setupMenu';

interface ImageIconProps {
  image: ForceImage;
  /** Card icons render the map symbol a bit larger than its marker size */
  scale?: number;
}

/** Map symbol as a sidebar card icon; the same `ForceImage` the markers use. */
export function ImageIcon({ image, scale = 1.4 }: ImageIconProps) {
  return (
    <img
      src={image.url ?? undefined}
      alt={image.label}
      width={image.width * scale}
      height={image.height * scale}
      className="shrink-0 object-contain"
    />
  );
}
