export const locales = ['ko', 'en'] as const;
export type Locale = (typeof locales)[number];

export function isLocale(value: string | undefined): value is Locale {
  return value === 'ko' || value === 'en';
}

/** Korean unless the browser prefers English over Korean. */
export function detectLocale(acceptLanguage: string | null | undefined): Locale {
  if (!acceptLanguage) return 'ko';
  const ranked = acceptLanguage
    .split(',')
    .map((part, index) => {
      const [tag, ...params] = part.trim().toLowerCase().split(';');
      const q = params.map((p) => p.trim()).find((p) => p.startsWith('q='));
      return { lang: tag.split('-')[0], q: q ? Number(q.slice(2)) : 1, index };
    })
    .filter((x) => x.lang && !Number.isNaN(x.q))
    .sort((a, b) => b.q - a.q || a.index - b.index);
  for (const { lang } of ranked) {
    if (lang === 'ko' || lang === 'en') return lang;
  }
  return 'ko';
}

/** "@jisu", "%40jisu" or "jisu" → "jisu"; null when it cannot be a gallery address. */
export function parseHandle(segment: string): string | null {
  let s: string;
  try {
    s = decodeURIComponent(segment);
  } catch {
    return null;
  }
  s = s.trim().toLowerCase().replace(/^@/, '');
  return /^[a-z0-9_]{3,30}$/.test(s) ? s : null;
}

/** The artist's English text when reading in English and it exists. */
export function pick(ko: string, en: string | null | undefined, locale: Locale): string {
  return locale === 'en' && en && en.trim() ? en : ko;
}

const ko = {
  tagline: '누구나 자신만의 작은 갤러리를 가질 수 있는 곳',
  intro: '아마추어 화가와 사진가의 작은 갤러리. 주소를 알면 바로 둘러볼 수 있어요.',
  visitLabel: '갤러리 주소',
  visit: '둘러보기',
  getApp: '내 갤러리 만들기',
  getAppBody: '이 웹에서 바로 만들고 관리할 수 있어요. Windows · Mac · iPhone · Android 앱도 같은 계정으로 씁니다.',
  startStudio: '무료로 시작하기',
  signInStudio: '로그인',
  manage: '스튜디오에서 관리',
  notFound: '갤러리를 찾을 수 없어요',
  notFoundBody: '주소를 다시 확인해 주세요. 비공개로 바뀐 갤러리일 수도 있어요.',
  home: '처음으로',
  works: (n: number) => `작품 ${n}`,
  rooms: (n: number) => `전시실 ${n}`,
  noWorks: '아직 걸린 작품이 없어요.',
  guestbook: '방명록',
  writeGuestbook: '방명록 남기기',
  comments: '감상평',
  writeComment: '감상평 남기기',
  send: '보내기',
  like: '공감',
  back: '갤러리로',
  prevWork: (title: string) => `이전 작품: ${title}`,
  nextWork: (title: string) => `다음 작품: ${title}`,
  position: (i: number, n: number) => `${i} / ${n}`,
  rateThis: '이 작품 평가하기',
  criteria: { composition: '구도', color: '색감', technique: '기술', emotion: '감성' },
  starLabel: (c: string, n: number) => `${c} ${n}점`,
  submitRating: '평가 남기기',
  updateRating: '평가 수정하기',
  ratingSent: '평가를 작가에게 전달했어요',
  ratingNote: '평가가 5건 이상 모이면 평균이 공개돼요. 작가에게는 바로 전달됩니다.',
  averages: (n: number) => `평균 평점 · ${n}명 참여`,
  ratingsOff: '작가가 평가를 받지 않는 작품이에요',
  ownWork: '내 작품은 평가할 수 없어요',
  signInPrompt: '로그인하면 평가와 감상평을 남길 수 있어요',
  email: '이메일',
  sendLink: '로그인 링크 받기',
  linkSent: '메일로 로그인 링크를 보냈어요. 링크를 열면 이 페이지로 돌아옵니다.',
  signOut: '로그아웃',
  pending: '작가가 승인하면 공개돼요',
  commentsClosed: '작가가 감상평을 받지 않고 있어요',
  blocked: '이 갤러리에는 감상평을 남길 수 없어요',
  error: '문제가 생겼어요. 잠시 후 다시 시도해 주세요.',
  share: '링크 복사',
  copied: '복사했어요',
  language: 'English',
} as const;

type Dict = {
  [K in keyof typeof ko]: (typeof ko)[K] extends (...args: infer A) => string
    ? (...args: A) => string
    : (typeof ko)[K] extends string
      ? string
      : { [P in keyof (typeof ko)[K]]: string };
};

const en: Dict = {
  tagline: 'Where anyone can have a small gallery of their own',
  intro: 'Small galleries by amateur painters and photographers. Know the address? Walk right in.',
  visitLabel: 'Gallery address',
  visit: 'Visit',
  getApp: 'Create your own gallery',
  getAppBody: 'Create and manage it right here on the web. The Windows, Mac, iPhone and Android apps use the same account.',
  startStudio: 'Start for free',
  signInStudio: 'Sign in',
  manage: 'Manage in studio',
  notFound: 'Gallery not found',
  notFoundBody: 'Check the address. The gallery may also have been made private.',
  home: 'Home',
  works: (n) => `${n} ${n === 1 ? 'work' : 'works'}`,
  rooms: (n) => `${n} ${n === 1 ? 'room' : 'rooms'}`,
  noWorks: 'Nothing on the walls yet.',
  guestbook: 'Guestbook',
  writeGuestbook: 'Sign the guestbook',
  comments: 'Comments',
  writeComment: 'Write a comment',
  send: 'Send',
  like: 'Like',
  back: 'Back to gallery',
  prevWork: (title) => `Previous work: ${title}`,
  nextWork: (title) => `Next work: ${title}`,
  position: (i, n) => `${i} of ${n}`,
  rateThis: 'Rate this work',
  criteria: { composition: 'Composition', color: 'Color', technique: 'Technique', emotion: 'Feeling' },
  starLabel: (c, n) => `${c}: ${n} stars`,
  submitRating: 'Send rating',
  updateRating: 'Update rating',
  ratingSent: 'Your rating went to the artist',
  ratingNote: 'Averages appear once 5 people have rated. The artist sees yours right away.',
  averages: (n) => `Average · ${n} ratings`,
  ratingsOff: "The artist isn't taking ratings for this work",
  ownWork: "You can't rate your own work",
  signInPrompt: 'Sign in to rate and comment',
  email: 'Email',
  sendLink: 'Email me a sign-in link',
  linkSent: 'We emailed you a sign-in link. Opening it brings you back here.',
  signOut: 'Sign out',
  pending: 'Visible once the artist approves it',
  commentsClosed: "The artist isn't taking comments",
  blocked: "You can't comment in this gallery",
  error: 'Something went wrong. Please try again shortly.',
  share: 'Copy link',
  copied: 'Copied',
  language: '한국어',
};

export type Messages = Dict;

export function messages(locale: Locale): Messages {
  return locale === 'en' ? en : (ko as unknown as Dict);
}
