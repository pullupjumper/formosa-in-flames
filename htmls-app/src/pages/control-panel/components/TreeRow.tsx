import type { ReactNode } from 'react';

// ============================================================================
// TreeRow — a root card on the left linked by blue lines to a column of cards
// ============================================================================
interface TreeRowProps {
  root: ReactNode;
  /** Cards on the right, one connector each; keys are the caller's */
  leaves: { key: string; node: ReactNode }[];
  emptyMessage: string;
}

// Tree connectors: a trunk 12px right of the root card, a stub from every card to it
const LINE = 'absolute bg-aip-link';

export function TreeRow({ root, leaves, emptyMessage }: TreeRowProps) {
  return (
    <div className="flex items-stretch">
      <div className="relative w-2/5 shrink-0 self-center">
        {root}
        {leaves.length > 0 && (
          <span className={`${LINE} top-1/2 -right-3 h-px w-3`} aria-hidden="true" />
        )}
      </div>

      <div className="ml-6 flex min-w-0 flex-1 flex-col gap-2">
        {leaves.length === 0 ? (
          <div className="self-center text-xs italic text-text-secondary">{emptyMessage}</div>
        ) : (
          leaves.map((leaf, index) => (
            <div key={leaf.key} className="relative">
              <Connector index={index} count={leaves.length} />
              {leaf.node}
            </div>
          ))
        )}
      </div>
    </div>
  );
}

// ============================================================================
// Connector — the trunk segment and stub for one leaf row
// ============================================================================
function Connector({ index, count }: { index: number; count: number }) {
  // Segments overshoot by the 8px row gap so neighbouring ones join into one trunk
  const trunkSpan =
    count === 1
      ? null
      : index === 0
        ? 'top-1/2 -bottom-2'
        : index === count - 1
          ? '-top-2 bottom-1/2'
          : '-top-2 -bottom-2';

  return (
    <>
      {trunkSpan && <span className={`${LINE} -left-3 w-px ${trunkSpan}`} aria-hidden="true" />}
      <span className={`${LINE} top-1/2 -left-3 h-px w-3`} aria-hidden="true" />
    </>
  );
}
