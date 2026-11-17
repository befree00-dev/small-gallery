# Small Gallery

아마추어 화가·사진가를 위한 개인 갤러리 서비스의 MVP입니다. 작가는 앱에서 작품을 올려 갤러리를 꾸미고, 방문자는 링크(`smallgallery.app/@handle`)로 앱 설치 없이 감상하고 평가합니다.

| 폴더 | 내용 | 기술 |
| --- | --- | --- |
| `supabase/` | DB 스키마, 권한 규칙(RLS), 트리거, 저장소 정책, 테스트 | PostgreSQL · Supabase |
| `app/` | 작가·방문자 앱 (Windows · macOS · iOS · Android) | Flutter 3.50 · Riverpod · go_router |
| `web/` | 방문자용 공개 웹 갤러리 (링크로 여는 화면) | Next.js 16 · React 19 |

한국어·영어를 처음부터 지원합니다. 앱과 웹 모두 언어 전환이 되고, 작가는 제목·소개·노트를 영어로 함께 적을 수 있습니다.

## MVP에 들어간 것

- **갤러리 만들기**: 가입 → 분야 선택 → 갤러리 이름·주소(@handle, 중복·예약어 검사) → 테마 3종(화이트 큐브 · 다크 룸 · 우드 프레임).
- **전시실**: 만들기 · 이름/서문/공개 범위 편집 · 삭제, 작품 순서 끌어서 바꾸기.
- **작품 올리기**: 여러 장 선택(모바일) · 끌어다 놓기(Windows·Mac), 작품별 제목·영어 제목·크기·노트, 공통 연도·재료·전시실·워터마크·평가 받기.
  - 기기 안에서 2048px 표시용 + 480px 썸네일을 만들고 **EXIF를 모두 지운 뒤** 올립니다(GPS 포함). 카메라·렌즈·ISO 등 보여줄 정보만 따로 저장합니다.
  - 원본은 작가만 읽을 수 있는 비공개 저장소에 둡니다.
- **방문자**: 로그인 없이 감상, 공감(기기당 1회, 다시 누르면 취소), 4항목 별점(구도·색감·기술·감성, 로그인 필요), 감상평·방명록.
- **상처 없는 피드백**: 평균 평점은 5명 이상 평가해야 방문자에게 공개(작가는 바로 봄), 감상평 승인제/바로 공개/끄기, 금칙어가 있으면 자동 승인 대기, 작성자 차단, 신고.
- **반응 탭**: 이번 주 방문 수 · 총 공감 · 승인 대기, 감상평 승인/숨기기/차단, 새 평가 알림.
- **요금제 한도**: Free 100점 / Plus 2,000점(DB에서 강제).
- **웹**: 언어 자동 감지(`/@jisu` → `/ko/@jisu` 또는 `/en/@jisu`), 링크 미리보기(OG 이미지), 우클릭 저장 방지, AI 학습 크롤러 차단(`robots.txt`, `X-Robots-Tag: noai`), 이메일 매직링크 로그인.

## 아직 없는 것 (다음 단계)

| 항목 | 지금 상태 |
| --- | --- |
| 푸시 알림 (FCM · APNs · Windows) | 알림은 `notifications` 테이블에 쌓이고 앱의 반응 탭에 보입니다. 기기로 보내는 부분은 없습니다. |
| 서버 이미지 처리 워커 | 리사이즈·EXIF 제거를 앱(기기)에서 합니다. WebP/AVIF 변환, 유해 이미지 자동 판별은 없습니다. |
| HEIC 파일 | 앱의 이미지 처리기(`image` 패키지)가 HEIC를 읽지 못해 "열 수 없는 이미지" 오류가 납니다. iPhone 사진 선택기가 JPEG로 바꿔 넘기는지는 실기기에서 확인이 필요하고, Mac에서 HEIC 파일을 직접 끌어다 놓으면 확실히 실패합니다. 서버 워커나 네이티브 변환이 필요합니다. |
| Plus 결제 | `profiles.plan` 값만 있고 결제·구독 연동은 없습니다. |
| 신고 처리 화면, 운영자 도구 | 신고는 `reports`에 쌓이기만 합니다. |
| 탐색 피드 · 팔로우 · 커스텀 도메인 | 기획서상 2차 범위입니다. |
| Windows에서 Google/Apple 로그인 | 커스텀 스킴 딥링크 등록이 더 필요합니다. 이메일 로그인은 모든 플랫폼에서 됩니다. |

## 설정

### 1. Supabase 프로젝트

1. [supabase.com](https://supabase.com)에서 프로젝트를 만듭니다.
2. `supabase/migrations/` 안의 SQL 두 개를 순서대로 실행합니다. SQL Editor에 붙여 넣거나 Supabase CLI로 `supabase db push`.
3. Authentication → URL Configuration에 다음을 추가합니다.
   - Site URL: 웹 주소 (예: `https://smallgallery.app`)
   - Redirect URLs: `app.smallgallery://login-callback`, `https://smallgallery.app/**`
4. Google·Apple 로그인을 쓰려면 Authentication → Providers에서 켭니다.
5. Project Settings → API에서 **Project URL**과 **anon(publishable) key**를 복사합니다.

### 2. 앱 (Flutter)

```bash
cd app
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://xxxx.supabase.co --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

플랫폼별 빌드는 각 OS에서 합니다(`flutter build windows`, `flutter build macos`, `flutter build ios`, `flutter build appbundle`). iOS·macOS는 Xcode에서 서명 팀을 지정해야 합니다.

플랫폼 설정에 이미 넣어 둔 것: 인터넷 권한(Android), 네트워크·사용자 선택 파일 읽기 권한(macOS), 사진·카메라 권한 문구(iOS), OAuth 복귀 주소 `app.smallgallery://login-callback`(iOS·Android).

### 3. 웹 (Next.js)

```bash
cd web
cp .env.example .env.local   # 값 채우기
npm install
npm run dev
```

Vercel 등에 배포할 때 같은 환경 변수를 넣습니다. 앱이 공유하는 링크 형식은 `https://smallgallery.app/@handle`입니다(`app/lib/ui/common.dart`의 `publicGalleryUrl`).

## 테스트

```bash
supabase/tests/run.sh          # 로컬 PostgreSQL 16+에서 스키마·RLS·트리거 검증
cd app && flutter analyze && flutter test
cd web && npm test && npm run typecheck && npm run build
```

- `supabase/tests/rls_test.sql`: 비공개 작품 숨김, 익명 공감, 5건 미만 평균 비공개, 본인 작품 평가 금지, 승인제 감상평, 차단, 저장소 경로 권한, 요금제 한도 등을 실제 PostgreSQL에서 확인합니다. Supabase의 `auth`·`storage` 스키마는 `supabase_shim.sql`이 흉내 냅니다.
- `app/test/`: 이미지 처리(크기, EXIF·GPS 제거, 회전, 워터마크), 온보딩, 업로드, 평가 패널, 라우팅을 메모리 속 가짜 저장소로 확인합니다.
- `web/tests/`: 언어 감지, 주소 해석, 리다이렉트 규칙, 번역 키 누락.

실제 Supabase 서버에 연결한 끝-대-끝 테스트는 아직 없습니다.

## 구조 메모

- 권한은 전부 DB(RLS)에서 지킵니다. 앱과 웹은 anon key만 쓰므로, 화면 코드가 잘못돼도 비공개 작품이나 5건 미만 평균이 새지 않습니다.
- 공감 수·감상평 수·평균은 트리거가 관리하고, 클라이언트는 이 값을 직접 고칠 수 없습니다.
- 표시용 이미지는 공개 버킷에 있어 URL을 알면 열립니다(경로에 추측 불가능한 UUID 포함). 비공개 작품의 이미지까지 막으려면 서명 URL로 바꿔야 합니다.
