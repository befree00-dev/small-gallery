import { describe, expect, it } from 'vitest';

import { average, groupByRoom } from '../lib/data';
import { detectLocale, messages, parseHandle, pick } from '../lib/i18n';
import { localeRedirect } from '../lib/locale-routing';
import type { Artwork, Room } from '../lib/types';

describe('detectLocale', () => {
  it('defaults to Korean', () => {
    expect(detectLocale(null)).toBe('ko');
    expect(detectLocale('fr-FR,fr;q=0.9')).toBe('ko');
  });

  it('honours the browser preference order and weights', () => {
    expect(detectLocale('en-US,en;q=0.9,ko;q=0.8')).toBe('en');
    expect(detectLocale('ko-KR,ko;q=0.9,en-US;q=0.8')).toBe('ko');
    expect(detectLocale('fr;q=0.9,en;q=0.5,ko;q=0.7')).toBe('ko');
    expect(detectLocale('ja,en-GB;q=0.8')).toBe('en');
  });
});

describe('parseHandle', () => {
  it('accepts the shared address forms', () => {
    expect(parseHandle('@jisu')).toBe('jisu');
    expect(parseHandle('%40Jisu')).toBe('jisu');
    expect(parseHandle('jisu_2025')).toBe('jisu_2025');
  });

  it('rejects anything that cannot be a gallery address', () => {
    expect(parseHandle('@ab')).toBeNull();
    expect(parseHandle('@ji-su')).toBeNull();
    expect(parseHandle('%E0%A4%A')).toBeNull();
  });
});

describe('localeRedirect', () => {
  it('sends shared links to the visitor language', () => {
    expect(localeRedirect('/@jisu', 'en-US,en;q=0.9', undefined)).toBe('/en/@jisu');
    expect(localeRedirect('/@jisu', 'ko-KR', undefined)).toBe('/ko/@jisu');
    expect(localeRedirect('/', null, undefined)).toBe('/ko');
  });

  it('prefers the language the visitor chose before', () => {
    expect(localeRedirect('/@jisu', 'en-US', 'ko')).toBe('/ko/@jisu');
  });

  it('leaves localized paths alone', () => {
    expect(localeRedirect('/en/@jisu/a/123', 'ko', undefined)).toBeNull();
  });
});

describe('pick', () => {
  it('uses English only when the artist wrote it', () => {
    expect(pick('봄', 'Spring', 'en')).toBe('Spring');
    expect(pick('봄', ' ', 'en')).toBe('봄');
    expect(pick('봄', 'Spring', 'ko')).toBe('봄');
  });
});

describe('messages', () => {
  it('has every Korean string in English too', () => {
    const ko = messages('ko');
    const en = messages('en');
    expect(Object.keys(en).sort()).toEqual(Object.keys(ko).sort());
    expect(en.works(1)).toBe('1 work');
    expect(ko.works(3)).toBe('작품 3');
  });
});

describe('groupByRoom', () => {
  const room = (id: string, sort_order: number): Room => ({ id, title: id, title_en: null, statement: '', statement_en: null, sort_order });
  const work = (id: string, room_id: string) => ({ id, room_id }) as Artwork;

  it('keeps room order and drops empty rooms', () => {
    const groups = groupByRoom([room('spring', 0), room('empty', 1), room('still', 2)], [work('a', 'still'), work('b', 'spring'), work('c', 'spring')]);
    expect(groups.map((g) => [g.room.id, g.artworks.map((a) => a.id)])).toEqual([
      ['spring', ['b', 'c']],
      ['still', ['a']],
    ]);
  });
});

describe('average', () => {
  it('reads Postgres numerics sent as strings', () => {
    expect(average('3.40')).toBe(3.4);
    expect(average(4)).toBe(4);
    expect(average(null)).toBe(0);
  });
});

describe('API embeds', () => {
  it('name the foreign key for every profiles embed', async () => {
    const { readFileSync } = await import('node:fs');
    const source = readFileSync(new URL('../lib/data.ts', import.meta.url), 'utf8');
    expect(source).not.toMatch(/profiles\(/);
  });
});
