import type { ReactNode, TdHTMLAttributes } from 'react';

/**
 * Document layout primitives for briefing-style tabs (OPORD, Game Mechanics).
 * Pure presentation; every component only wraps children in the shared styling.
 */

interface ChildrenProps {
  children: ReactNode;
}

interface TitledProps extends ChildrenProps {
  title: string;
}

export function Section({ title, children }: TitledProps) {
  return (
    <section className="mb-6">
      <div className="mb-2.5 border-b border-dark-border pb-2 text-base font-semibold uppercase tracking-wide text-accent-blue">
        {title}
      </div>
      {children}
    </section>
  );
}

export function Subsection({ title, children }: TitledProps) {
  return (
    <div className="mb-4 ml-5">
      <SubTitle>{title}</SubTitle>
      {children}
    </div>
  );
}

export function SubTitle({ children }: ChildrenProps) {
  return <div className="mb-1.5 text-[13px] font-semibold text-text-primary">{children}</div>;
}

export function Paragraph({ children }: ChildrenProps) {
  return <p className="my-2 text-[13px] leading-relaxed text-text-secondary">{children}</p>;
}

export function Indent({ children }: ChildrenProps) {
  return <div className="ml-5 mt-3">{children}</div>;
}

export function List({ children }: ChildrenProps) {
  return (
    <ul className="my-1.5 ml-6 list-disc space-y-1 text-[13px] leading-relaxed text-text-secondary">
      {children}
    </ul>
  );
}

export function Panel({ children }: ChildrenProps) {
  return (
    <div className="my-2.5 rounded-sm border border-dark-border bg-black/30 p-3">{children}</div>
  );
}

export function Term({ children }: ChildrenProps) {
  return <span className="font-semibold text-text-primary">{children}</span>;
}

export function Caption({ children }: ChildrenProps) {
  return (
    <div className="mb-2.5 mt-1.5 text-center text-xs italic text-text-secondary">{children}</div>
  );
}

interface FigureProps extends ChildrenProps {
  caption: string;
}

export function Figure({ caption, children }: FigureProps) {
  return (
    <div className="my-4">
      <div className="overflow-hidden rounded-sm border border-dark-border bg-dark-bg">
        {children}
      </div>
      <Caption>{caption}</Caption>
    </div>
  );
}

interface ScreenshotProps {
  src: string;
  alt: string;
}

export function Screenshot({ src, alt }: ScreenshotProps) {
  return <img src={src} alt={alt} className="block w-full" />;
}

interface DocTableProps extends ChildrenProps {
  headers: readonly string[];
}

/** Compact bordered table; `children` are the `<tr>` rows. */
export function DocTable({ headers, children }: DocTableProps) {
  return (
    <div className="my-2.5 overflow-x-auto">
      <table className="w-full border-collapse text-xs">
        <thead>
          <tr>
            {headers.map((header) => (
              <th
                key={header}
                className="border border-dark-border bg-dark-bg px-2 py-1.5 text-left font-semibold text-text-primary"
              >
                {header}
              </th>
            ))}
          </tr>
        </thead>
        <tbody>{children}</tbody>
      </table>
    </div>
  );
}

interface DocTdProps extends TdHTMLAttributes<HTMLTableCellElement> {
  children: ReactNode;
}

export function DocTd({ children, className = 'text-text-secondary', ...props }: DocTdProps) {
  return (
    <td className={`border border-dark-border px-2 py-1.5 ${className}`} {...props}>
      {children}
    </td>
  );
}
