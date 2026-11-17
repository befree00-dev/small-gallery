// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Small Gallery';

  @override
  String get welcomeHeadline => '누구나 자기 작품의 관장이 되는 곳';

  @override
  String get welcomeBody => '작품을 올리면 바로 나만의 작은 갤러리가 열립니다.';

  @override
  String get signIn => '로그인';

  @override
  String get signUp => '가입하기';

  @override
  String get email => '이메일';

  @override
  String get password => '비밀번호';

  @override
  String get displayName => '이름(작가명)';

  @override
  String get continueWithGoogle => 'Google로 계속하기';

  @override
  String get continueWithApple => 'Apple로 계속하기';

  @override
  String get haveAccount => '이미 계정이 있어요';

  @override
  String get needAccount => '처음이에요';

  @override
  String get visitByHandle => '갤러리 주소로 둘러보기';

  @override
  String get handleHint => '예: jisu';

  @override
  String get go => '이동';

  @override
  String get authFailed => '로그인하지 못했어요. 이메일과 비밀번호를 확인해 주세요.';

  @override
  String get checkEmail => '확인 메일을 보냈어요. 메일의 링크를 누른 뒤 로그인해 주세요.';

  @override
  String get passwordRule => '8자 이상';

  @override
  String get onboardingTitle => '갤러리 열기';

  @override
  String get stepField => '어떤 작품을 하시나요?';

  @override
  String get fieldPainting => '회화';

  @override
  String get fieldPhoto => '사진';

  @override
  String get fieldIllustration => '일러스트';

  @override
  String get fieldOther => '기타';

  @override
  String get galleryTitle => '갤러리 이름';

  @override
  String get galleryAddress => '갤러리 주소';

  @override
  String get handleRule => '영문 소문자, 숫자, _ 3–30자';

  @override
  String get handleTaken => '이미 쓰이고 있는 주소예요';

  @override
  String get theme => '테마';

  @override
  String get themeWhite => '화이트 큐브';

  @override
  String get themeDark => '다크 룸';

  @override
  String get themeWood => '우드 프레임';

  @override
  String get firstRoomName => '첫 번째 전시실';

  @override
  String get next => '다음';

  @override
  String get back => '이전';

  @override
  String get openGallery => '갤러리 열기';

  @override
  String get tabGallery => '갤러리';

  @override
  String get tabUpload => '업로드';

  @override
  String get tabReactions => '반응';

  @override
  String get tabSettings => '설정';

  @override
  String get rooms => '전시실';

  @override
  String get newRoom => '새 전시실';

  @override
  String get roomTitle => '전시실 이름';

  @override
  String get roomStatement => '전시 서문';

  @override
  String artworksCount(int count) {
    return '작품 $count점';
  }

  @override
  String get viewAsVisitor => '방문자 시점으로 보기';

  @override
  String get shareGallery => '갤러리 링크 복사';

  @override
  String get linkCopied => '링크를 복사했어요';

  @override
  String get emptyRoom => '아직 걸린 작품이 없어요. 첫 작품을 올려 보세요.';

  @override
  String get emptyGallery => '전시실을 만들고 작품을 걸어 보세요.';

  @override
  String get visibility => '공개 범위';

  @override
  String get visibilityPublic => '전체 공개';

  @override
  String get visibilityUnlisted => '링크가 있는 사람만';

  @override
  String get visibilityPrivate => '비공개';

  @override
  String get delete => '삭제';

  @override
  String get cancel => '취소';

  @override
  String get save => '저장';

  @override
  String get saved => '저장했어요';

  @override
  String get deleteRoomConfirm => '이 전시실과 안의 작품이 모두 삭제됩니다. 계속할까요?';

  @override
  String get deleteArtworkConfirm => '이 작품을 삭제할까요? 받은 평가와 감상평도 함께 지워집니다.';

  @override
  String get dragToReorder => '끌어서 순서를 바꾸면 방문자 화면에도 같은 순서로 걸립니다.';

  @override
  String get featured => '대표 작품';

  @override
  String get editArtwork => '작품 정보 수정';

  @override
  String get uploadTitle => '작품 올리기';

  @override
  String get pickPhotos => '사진 선택';

  @override
  String get dropHere => '여기로 사진을 끌어다 놓으세요';

  @override
  String get dropFormats => 'JPEG · PNG · HEIC · WebP, 한 장에 최대 50MB';

  @override
  String get gpsRemoved => '위치 정보(GPS)는 자동으로 지워져요';

  @override
  String get title => '제목';

  @override
  String get titleEn => '영어 제목 (선택)';

  @override
  String get year => '제작연도';

  @override
  String get size => '크기';

  @override
  String get medium => '재료 · 기법';

  @override
  String get mediumWatercolor => '수채화';

  @override
  String get mediumOil => '유화';

  @override
  String get mediumAcrylic => '아크릴';

  @override
  String get mediumPhoto => '사진';

  @override
  String get mediumDigital => '디지털';

  @override
  String get mediumOther => '기타';

  @override
  String get artistNote => '작가 노트';

  @override
  String get artistNoteEn => '영어 작가 노트 (선택)';

  @override
  String get room => '전시실';

  @override
  String get watermark => '작가명 워터마크 넣기';

  @override
  String get acceptRatings => '방문자 평가 받기';

  @override
  String get hangArtwork => '전시실에 걸기';

  @override
  String uploading(int done, int total) {
    return '$total장 중 $done장 올리는 중';
  }

  @override
  String get uploadDone => '작품을 걸었어요';

  @override
  String get fileTooLarge => '50MB가 넘는 파일은 올릴 수 없어요';

  @override
  String get unsupportedImage => '열 수 없는 이미지예요';

  @override
  String get quotaExceeded => '무료 플랜은 작품 100점까지 올릴 수 있어요';

  @override
  String get titleRequired => '제목을 입력해 주세요';

  @override
  String get needRoom => '먼저 전시실을 만들어 주세요';

  @override
  String get reactionsTitle => '반응';

  @override
  String get visitorsThisWeek => '이번 주 방문';

  @override
  String get likes => '공감';

  @override
  String get newComments => '새 감상평';

  @override
  String get pendingApproval => '승인 대기';

  @override
  String get approve => '승인';

  @override
  String get hide => '숨기기';

  @override
  String get blockAuthor => '작성자 차단';

  @override
  String get report => '신고';

  @override
  String notifRating(String title) {
    return '새 평가 · $title';
  }

  @override
  String notifComment(String title) {
    return '새 감상평 · $title';
  }

  @override
  String get notifGuestbook => '방명록에 새 글';

  @override
  String get notifPending => '승인을 기다리는 감상평';

  @override
  String get noReactions => '아직 반응이 없어요. 갤러리 링크를 공유해 보세요.';

  @override
  String get settingsTitle => '설정';

  @override
  String get galleryInfo => '갤러리 정보';

  @override
  String get bio => '작가 소개';

  @override
  String get bioEn => '영어 작가 소개 (선택)';

  @override
  String get ratingsOnGallery => '방문자 평가 받기 (갤러리 전체)';

  @override
  String get commentPolicy => '감상평';

  @override
  String get policyOpen => '바로 공개';

  @override
  String get policyApprove => '승인 후 공개';

  @override
  String get policyOff => '받지 않음';

  @override
  String get language => '언어';

  @override
  String get signOut => '로그아웃';

  @override
  String planUsage(String plan, int count, int limit) {
    return '$plan 플랜 · $count / $limit점';
  }

  @override
  String galleryStats(int artworks, int rooms) {
    return '작품 $artworks · 전시실 $rooms';
  }

  @override
  String get guestbook => '방명록';

  @override
  String get writeGuestbook => '방명록 남기기';

  @override
  String get galleryNotFound => '갤러리를 찾을 수 없어요';

  @override
  String get like => '공감';

  @override
  String get comments => '감상평';

  @override
  String get rateThis => '이 작품 평가하기';

  @override
  String get composition => '구도';

  @override
  String get color => '색감';

  @override
  String get technique => '기술';

  @override
  String get emotion => '감성';

  @override
  String get submitRating => '평가 남기기';

  @override
  String get updateRating => '평가 수정하기';

  @override
  String get ratingSent => '평가를 작가에게 전달했어요';

  @override
  String get ratingNote => '평가가 5건 이상 모이면 평균이 공개돼요. 작가에게는 바로 전달됩니다.';

  @override
  String ratingAverages(int count) {
    return '평균 평점 · $count명 참여';
  }

  @override
  String get signInToReact => '로그인하면 평가와 감상평을 남길 수 있어요';

  @override
  String get writeComment => '감상평 남기기';

  @override
  String get commentPending => '작가가 승인하면 공개돼요';

  @override
  String get commentsClosed => '작가가 감상평을 받지 않고 있어요';

  @override
  String get ratingsOff => '작가가 평가를 받지 않는 작품이에요';

  @override
  String get ownArtwork => '내 작품은 평가할 수 없어요';

  @override
  String starLabel(String criterion, int n) {
    return '$criterion $n점';
  }

  @override
  String get send => '보내기';

  @override
  String get loadFailed => '불러오지 못했어요. 다시 시도해 주세요.';

  @override
  String get retry => '다시 시도';

  @override
  String get somethingWrong => '문제가 생겼어요. 잠시 후 다시 시도해 주세요.';
}
