import { useRef, type PointerEvent } from 'react';

// ============================================================================
// ResizeHandle — vertical splitter that drags the left column's width
// ============================================================================
interface ResizeHandleProps {
  width: number;
  minWidth: number;
  maxWidth: number;
  onWidthChange: (width: number) => void;
}

export function ResizeHandle({ width, minWidth, maxWidth, onWidthChange }: ResizeHandleProps) {
  const dragStart = useRef<{ pointerX: number; width: number } | null>(null);

  const handlePointerDown = (event: PointerEvent<HTMLDivElement>) => {
    // Capture keeps move events coming when the cursor drags over the map
    event.currentTarget.setPointerCapture(event.pointerId);
    dragStart.current = { pointerX: event.clientX, width };
  };

  const handlePointerMove = (event: PointerEvent<HTMLDivElement>) => {
    const start = dragStart.current;
    if (!start) return;
    const next = start.width + event.clientX - start.pointerX;
    onWidthChange(Math.min(maxWidth, Math.max(minWidth, next)));
  };

  const handlePointerUp = (event: PointerEvent<HTMLDivElement>) => {
    dragStart.current = null;
    event.currentTarget.releasePointerCapture(event.pointerId);
  };

  return (
    <div
      role="separator"
      aria-orientation="vertical"
      className="w-1.5 shrink-0 cursor-col-resize touch-none bg-aip-border transition-colors hover:bg-aip-link"
      onPointerDown={handlePointerDown}
      onPointerMove={handlePointerMove}
      onPointerUp={handlePointerUp}
      onPointerCancel={handlePointerUp}
    />
  );
}
