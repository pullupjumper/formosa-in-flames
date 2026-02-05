import type { ReactNode, ThHTMLAttributes, TdHTMLAttributes } from 'react';

interface TableProps {
  children: ReactNode;
}

export function Table({ children }: TableProps) {
  return <table className="w-full border-collapse text-left text-[13px]">{children}</table>;
}

interface ThProps extends ThHTMLAttributes<HTMLTableCellElement> {
  children: ReactNode;
}

export function Th({ children, className = '', ...props }: ThProps) {
  return (
    <th
      className={`whitespace-nowrap border-b border-dark-border bg-black/20 px-4 py-3 text-xs font-semibold uppercase tracking-[0.05em] text-text-secondary ${className}`}
      {...props}
    >
      {children}
    </th>
  );
}

interface TdProps extends TdHTMLAttributes<HTMLTableCellElement> {
  children: ReactNode;
}

export function Td({ children, className = '', ...props }: TdProps) {
  return (
    <td
      className={`border-b border-dark-border px-4 py-3 text-text-primary ${className}`}
      {...props}
    >
      {children}
    </td>
  );
}

interface TrProps {
  children: ReactNode;
}

export function Tr({ children }: TrProps) {
  return <tr className="hover:bg-white/2">{children}</tr>;
}

interface EmptyRowProps {
  colSpan: number;
  message?: string;
}

export function EmptyRow({ colSpan, message = 'No data available' }: EmptyRowProps) {
  return (
    <Tr>
      <Td colSpan={colSpan} className="text-center text-text-secondary">
        {message}
      </Td>
    </Tr>
  );
}

interface ProgressBarProps {
  percentage: number;
}

export function ProgressBar({ percentage }: ProgressBarProps) {
  return (
    <div className="min-w-25">
      <div className="h-1.5 overflow-hidden rounded-sm bg-black/30">
        <div
          className="h-full bg-accent-blue transition-[width] duration-300"
          style={{ width: `${percentage}%` }}
        />
      </div>
      <div className="mt-1 text-right text-[10px] text-text-secondary">{percentage}%</div>
    </div>
  );
}

interface StatusBadgeProps {
  variant: 'ready' | 'offline' | 'standby';
  children: ReactNode;
}

export function StatusBadge({ variant, children }: StatusBadgeProps) {
  const variantClasses = {
    ready: 'bg-status-success/20 text-status-success border-status-success/30',
    offline: 'bg-status-danger/20 text-status-danger border-status-danger/30',
    standby: 'bg-status-warning/20 text-status-warning border-status-warning/30',
  };

  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded px-2 py-1 text-[11px] font-semibold uppercase ${variantClasses[variant]} border`}
    >
      {children}
    </span>
  );
}
