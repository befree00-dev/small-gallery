import Link from 'next/link';

/**
 * The Small Gallery mark: a framed picture hanging from a nail, as on a gallery wall.
 * The frame follows the text color, so it works on light and dark themes.
 */
export function LogoMark({ size = 28 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden="true" focusable="false" className="logo-mark">
      {/* A picture hung on a gallery wall: nail, wire, frame, and a hill under a low sun. */}
      <path d="M6.5 11.5 16 3.6l9.5 7.9" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinejoin="round" />
      <circle cx="16" cy="3.4" r="1.7" fill="currentColor" />
      <rect x="3.2" y="11" width="25.6" height="18.6" rx="2.6" fill="none" stroke="currentColor" strokeWidth="2.4" />
      <rect x="7.4" y="15.2" width="17.2" height="10.2" rx="0.8" fill="var(--logo-sky, #e8ecf8)" />
      <circle cx="19.6" cy="18.6" r="1.9" fill="#e8b04b" />
      <path d="M7.4 22.4c2.4-2 4.8-2.7 7.2-1.6 1.6.7 2.8.8 4.3.1 1.9-.9 3.9-1.1 5.7-.4v4.9H7.4z" fill="var(--logo-hill, #2e4aa6)" />
    </svg>
  );
}

/** Mark plus wordmark, linking home. */
export function Logo({ href, label = 'Small Gallery' }: { href: string; label?: string }) {
  return (
    <Link href={href} className="logo" aria-label={`${label} — home`}>
      <LogoMark />
      <span className="logo-word" aria-hidden="true">
        Small <em>Gallery</em>
      </span>
    </Link>
  );
}
