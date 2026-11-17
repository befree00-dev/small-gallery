import { redirect } from 'next/navigation';

import { isLocale, messages, parseHandle } from '@/lib/i18n';
import { siteOrigin } from '@/lib/site';

export default async function Home({
  params,
  searchParams,
}: {
  params: Promise<{ locale: string }>;
  searchParams: Promise<{ handle?: string }>;
}) {
  const { locale: raw } = await params;
  const locale = isLocale(raw) ? raw : 'ko';
  const t = messages(locale);
  const { handle } = await searchParams;
  const siteHost = new URL(await siteOrigin()).host;

  // The address form submits here as ?handle=…; send valid ones to the gallery.
  const parsed = handle ? parseHandle(handle.split('/').pop() ?? '') : null;
  if (parsed) redirect(`/${locale}/@${parsed}`);

  return (
    <main className="page">
      <div className="wrap">
        <header className="topbar">
          <span className="address">Small Gallery</span>
          <a className="btn btn-quiet" href={locale === 'ko' ? '/en' : '/ko'} hrefLang={locale === 'ko' ? 'en' : 'ko'}>
            {t.language}
          </a>
        </header>
      </div>
      <section className="home">
        <h1 className="title">{t.tagline}</h1>
        <p className="bio">{t.intro}</p>
        <form action={`/${locale}`} method="get">
          <label htmlFor="handle" className="visually-hidden">{t.visitLabel}</label>
          <div className="prefix">
            <span aria-hidden="true">{siteHost}/@</span>
            <input id="handle" name="handle" autoComplete="off" autoCapitalize="none" spellCheck={false} required defaultValue={handle ?? ''} />
          </div>
          <button className="btn btn-primary" type="submit">{t.visit}</button>
        </form>
        <div style={{ marginTop: 32 }}>
          <h2 style={{ fontSize: 16, margin: '0 0 4px' }}>{t.getApp}</h2>
          <p className="meta" style={{ margin: 0 }}>{t.getAppBody}</p>
        </div>
      </section>
    </main>
  );
}
