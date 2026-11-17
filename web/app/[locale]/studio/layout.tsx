import type { Metadata } from 'next';
import { notFound } from 'next/navigation';
import type { ReactNode } from 'react';

import { StudioShell } from '@/components/studio/shell';
import { isLocale } from '@/lib/i18n';

export const metadata: Metadata = { title: 'Studio', robots: { index: false, follow: false } };

export default async function StudioLayout({ children, params }: { children: ReactNode; params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  return <StudioShell locale={locale}>{children}</StudioShell>;
}
