import type { Metadata, Viewport } from 'next';
import { notFound } from 'next/navigation';
import type { ReactNode } from 'react';

import { isLocale, messages } from '@/lib/i18n';
import { siteOrigin } from '@/lib/site';

import '../globals.css';

export async function generateMetadata({ params }: { params: Promise<{ locale: string }> }): Promise<Metadata> {
  const { locale } = await params;
  const t = messages(isLocale(locale) ? locale : 'ko');
  return {
    title: { default: 'Small Gallery', template: '%s · Small Gallery' },
    description: t.intro,
    metadataBase: new URL(await siteOrigin()),
  };
}

export const viewport: Viewport = { themeColor: '#F6F5F1', width: 'device-width', initialScale: 1 };

export default async function LocaleLayout({ children, params }: { children: ReactNode; params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  if (!isLocale(locale)) notFound();
  return (
    <html lang={locale}>
      <head>
        <link rel="preconnect" href="https://fonts.googleapis.com" />
        <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="" />
        {/* eslint-disable-next-line @next/next/no-page-custom-font */}
        <link
          rel="stylesheet"
          href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&family=Noto+Serif+KR:wght@400;600;900&display=swap"
        />
      </head>
      <body>{children}</body>
    </html>
  );
}
