'use client';

import { useState } from 'react';

import type { Day } from '@/lib/admin/api';
import type { AdminStrings } from '@/lib/admin/messages';
import type { Locale } from '@/lib/i18n';

// Drawn near the size it is shown at (~320–380px), so 11px labels stay 11px.
const W = 360;
const H = 150;
const PAD = { top: 10, right: 4, bottom: 22, left: 30 };

/** A rounded-up axis maximum with 2–4 even steps (1, 2, 5 × 10ⁿ). */
export function niceMax(max: number): { top: number; step: number } {
  if (max <= 0) return { top: 4, step: 2 };
  const raw = max / 3;
  const mag = 10 ** Math.floor(Math.log10(raw));
  const step = [1, 2, 5, 10].map((m) => m * mag).find((s) => s >= raw) ?? 10 * mag;
  const s = Math.max(1, step);
  return { top: Math.ceil(max / s) * s, step: s };
}

/** Bar path with a 4px rounded top, square at the baseline. */
function bar(x: number, y: number, w: number, h: number) {
  const r = Math.min(4, w / 2, h);
  return `M${x} ${y + h}V${y + r}Q${x} ${y} ${x + r} ${y}H${x + w - r}Q${x + w} ${y} ${x + w} ${y + r}V${y + h}Z`;
}

/** One measure per day, last 30 days. Hover a day for its value; the table holds every number. */
export function DailyBars({
  title,
  days,
  field,
  locale,
  t,
}: {
  title: string;
  days: Day[];
  field: 'views' | 'galleries' | 'comments';
  locale: Locale;
  t: AdminStrings;
}) {
  const [hover, setHover] = useState<number | null>(null);
  const values = days.map((d) => d[field]);
  const { top, step } = niceMax(Math.max(0, ...values));
  const total = values.reduce((s, v) => s + v, 0);
  const plotW = W - PAD.left - PAD.right;
  const plotH = H - PAD.top - PAD.bottom;
  const slot = plotW / Math.max(1, days.length);
  const gap = Math.min(2, slot / 4);
  const barW = Math.max(1, slot - gap);
  const y = (v: number) => PAD.top + plotH - (v / top) * plotH;
  const fmt = new Intl.DateTimeFormat(locale === 'ko' ? 'ko-KR' : 'en-US', { month: 'short', day: 'numeric', timeZone: 'UTC' });
  const label = (d: string) => fmt.format(new Date(`${d}T00:00:00Z`));
  const num = new Intl.NumberFormat(locale === 'ko' ? 'ko-KR' : 'en-US');
  const ticks = Array.from({ length: Math.round(top / step) + 1 }, (_, i) => i * step);
  const xLabels = days.length ? [0, Math.floor((days.length - 1) / 2), days.length - 1] : [];
  const tipLeft = hover === null ? 0 : ((PAD.left + hover * slot + slot / 2) / W) * 100;

  return (
    <figure className="chart">
      <figcaption>
        <span className="chart-title">{title}</span>
        <span className="chart-total">{t.last30} · {num.format(total)}</span>
      </figcaption>
      <div className="chart-plot" onMouseLeave={() => setHover(null)}>
        <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label={`${title}, ${t.last30}: ${num.format(total)}`}>
          {ticks.map((v) => (
            <g key={v}>
              <line x1={PAD.left} x2={W - PAD.right} y1={y(v)} y2={y(v)} className={v === 0 ? 'chart-baseline' : 'chart-grid'} />
              <text x={PAD.left - 6} y={y(v) + 4} textAnchor="end" className="chart-tick">{num.format(v)}</text>
            </g>
          ))}
          {days.map((d, i) => {
            const v = values[i];
            const x = PAD.left + i * slot + gap / 2;
            return (
              <g key={d.day}>
                {v > 0 && <path d={bar(x, y(v), barW, PAD.top + plotH - y(v))} className="chart-bar" data-active={hover === i} />}
                {/* Hit target: the whole column, not just the bar. */}
                <rect x={PAD.left + i * slot} y={PAD.top} width={slot} height={plotH} fill="transparent" onMouseEnter={() => setHover(i)} />
              </g>
            );
          })}
          {xLabels.map((i) => (
            <text key={i} x={PAD.left + i * slot + slot / 2} y={H - 8} textAnchor={i === 0 ? 'start' : i === days.length - 1 ? 'end' : 'middle'} className="chart-tick">
              {label(days[i].day)}
            </text>
          ))}
        </svg>
        {hover !== null && (
          <div className="chart-tip" style={{ left: `${tipLeft}%` }} role="status">
            <span>{label(days[hover].day)}</span> <strong>{num.format(values[hover])}</strong>
          </div>
        )}
      </div>
      <details className="chart-table">
        <summary>{t.showTable}</summary>
        <table>
          <thead>
            <tr><th scope="col">{t.date}</th><th scope="col">{title}</th></tr>
          </thead>
          <tbody>
            {[...days].reverse().map((d, i) => (
              <tr key={d.day}><td>{label(d.day)}</td><td>{num.format(values[days.length - 1 - i])}</td></tr>
            ))}
          </tbody>
        </table>
      </details>
    </figure>
  );
}
