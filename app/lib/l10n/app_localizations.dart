import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In ko, this message translates to:
  /// **'Small Gallery'**
  String get appTitle;

  /// No description provided for @welcomeHeadline.
  ///
  /// In ko, this message translates to:
  /// **'누구나 자신만의 작은 갤러리를 가질 수 있는 곳'**
  String get welcomeHeadline;

  /// No description provided for @welcomeBody.
  ///
  /// In ko, this message translates to:
  /// **'작품을 올리면 바로 나만의 작은 갤러리가 열립니다.'**
  String get welcomeBody;

  /// No description provided for @signIn.
  ///
  /// In ko, this message translates to:
  /// **'로그인'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In ko, this message translates to:
  /// **'가입하기'**
  String get signUp;

  /// No description provided for @email.
  ///
  /// In ko, this message translates to:
  /// **'이메일'**
  String get email;

  /// No description provided for @password.
  ///
  /// In ko, this message translates to:
  /// **'비밀번호'**
  String get password;

  /// No description provided for @displayName.
  ///
  /// In ko, this message translates to:
  /// **'이름(작가명)'**
  String get displayName;

  /// No description provided for @continueWithGoogle.
  ///
  /// In ko, this message translates to:
  /// **'Google로 계속하기'**
  String get continueWithGoogle;

  /// No description provided for @continueWithApple.
  ///
  /// In ko, this message translates to:
  /// **'Apple로 계속하기'**
  String get continueWithApple;

  /// No description provided for @haveAccount.
  ///
  /// In ko, this message translates to:
  /// **'이미 계정이 있어요'**
  String get haveAccount;

  /// No description provided for @needAccount.
  ///
  /// In ko, this message translates to:
  /// **'처음이에요'**
  String get needAccount;

  /// No description provided for @visitByHandle.
  ///
  /// In ko, this message translates to:
  /// **'갤러리 주소로 둘러보기'**
  String get visitByHandle;

  /// No description provided for @handleHint.
  ///
  /// In ko, this message translates to:
  /// **'예: jisu'**
  String get handleHint;

  /// No description provided for @go.
  ///
  /// In ko, this message translates to:
  /// **'이동'**
  String get go;

  /// No description provided for @authFailed.
  ///
  /// In ko, this message translates to:
  /// **'로그인하지 못했어요. 이메일과 비밀번호를 확인해 주세요.'**
  String get authFailed;

  /// No description provided for @checkEmail.
  ///
  /// In ko, this message translates to:
  /// **'확인 메일을 보냈어요. 메일의 링크를 누른 뒤 로그인해 주세요.'**
  String get checkEmail;

  /// No description provided for @passwordRule.
  ///
  /// In ko, this message translates to:
  /// **'8자 이상'**
  String get passwordRule;

  /// No description provided for @onboardingTitle.
  ///
  /// In ko, this message translates to:
  /// **'내 갤러리 만들기'**
  String get onboardingTitle;

  /// No description provided for @stepField.
  ///
  /// In ko, this message translates to:
  /// **'어떤 작품을 하시나요?'**
  String get stepField;

  /// No description provided for @fieldPainting.
  ///
  /// In ko, this message translates to:
  /// **'회화'**
  String get fieldPainting;

  /// No description provided for @fieldPhoto.
  ///
  /// In ko, this message translates to:
  /// **'사진'**
  String get fieldPhoto;

  /// No description provided for @fieldIllustration.
  ///
  /// In ko, this message translates to:
  /// **'일러스트'**
  String get fieldIllustration;

  /// No description provided for @fieldOther.
  ///
  /// In ko, this message translates to:
  /// **'기타'**
  String get fieldOther;

  /// No description provided for @galleryTitle.
  ///
  /// In ko, this message translates to:
  /// **'갤러리 이름'**
  String get galleryTitle;

  /// No description provided for @galleryAddress.
  ///
  /// In ko, this message translates to:
  /// **'갤러리 주소'**
  String get galleryAddress;

  /// No description provided for @handleRule.
  ///
  /// In ko, this message translates to:
  /// **'영문 소문자, 숫자, _ 3–30자'**
  String get handleRule;

  /// No description provided for @handleTaken.
  ///
  /// In ko, this message translates to:
  /// **'이미 쓰이고 있는 주소예요'**
  String get handleTaken;

  /// No description provided for @theme.
  ///
  /// In ko, this message translates to:
  /// **'테마'**
  String get theme;

  /// No description provided for @themeWhite.
  ///
  /// In ko, this message translates to:
  /// **'화이트 큐브'**
  String get themeWhite;

  /// No description provided for @themeDark.
  ///
  /// In ko, this message translates to:
  /// **'다크 룸'**
  String get themeDark;

  /// No description provided for @themeWood.
  ///
  /// In ko, this message translates to:
  /// **'우드 프레임'**
  String get themeWood;

  /// No description provided for @firstRoomName.
  ///
  /// In ko, this message translates to:
  /// **'첫 번째 전시실'**
  String get firstRoomName;

  /// No description provided for @next.
  ///
  /// In ko, this message translates to:
  /// **'다음'**
  String get next;

  /// No description provided for @back.
  ///
  /// In ko, this message translates to:
  /// **'이전'**
  String get back;

  /// No description provided for @openGallery.
  ///
  /// In ko, this message translates to:
  /// **'갤러리 열기'**
  String get openGallery;

  /// No description provided for @tabGallery.
  ///
  /// In ko, this message translates to:
  /// **'갤러리'**
  String get tabGallery;

  /// No description provided for @tabUpload.
  ///
  /// In ko, this message translates to:
  /// **'업로드'**
  String get tabUpload;

  /// No description provided for @tabReactions.
  ///
  /// In ko, this message translates to:
  /// **'반응'**
  String get tabReactions;

  /// No description provided for @tabSettings.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get tabSettings;

  /// No description provided for @rooms.
  ///
  /// In ko, this message translates to:
  /// **'전시실'**
  String get rooms;

  /// No description provided for @newRoom.
  ///
  /// In ko, this message translates to:
  /// **'새 전시실'**
  String get newRoom;

  /// No description provided for @roomTitle.
  ///
  /// In ko, this message translates to:
  /// **'전시실 이름'**
  String get roomTitle;

  /// No description provided for @roomStatement.
  ///
  /// In ko, this message translates to:
  /// **'전시 서문'**
  String get roomStatement;

  /// No description provided for @artworksCount.
  ///
  /// In ko, this message translates to:
  /// **'작품 {count}점'**
  String artworksCount(int count);

  /// No description provided for @viewAsVisitor.
  ///
  /// In ko, this message translates to:
  /// **'방문자 시점으로 보기'**
  String get viewAsVisitor;

  /// No description provided for @shareGallery.
  ///
  /// In ko, this message translates to:
  /// **'갤러리 링크 복사'**
  String get shareGallery;

  /// No description provided for @linkCopied.
  ///
  /// In ko, this message translates to:
  /// **'링크를 복사했어요'**
  String get linkCopied;

  /// No description provided for @emptyRoom.
  ///
  /// In ko, this message translates to:
  /// **'아직 걸린 작품이 없어요. 첫 작품을 올려 보세요.'**
  String get emptyRoom;

  /// No description provided for @emptyGallery.
  ///
  /// In ko, this message translates to:
  /// **'전시실을 만들고 작품을 걸어 보세요.'**
  String get emptyGallery;

  /// No description provided for @visibility.
  ///
  /// In ko, this message translates to:
  /// **'공개 범위'**
  String get visibility;

  /// No description provided for @visibilityPublic.
  ///
  /// In ko, this message translates to:
  /// **'전체 공개'**
  String get visibilityPublic;

  /// No description provided for @visibilityUnlisted.
  ///
  /// In ko, this message translates to:
  /// **'링크가 있는 사람만'**
  String get visibilityUnlisted;

  /// No description provided for @visibilityPrivate.
  ///
  /// In ko, this message translates to:
  /// **'비공개'**
  String get visibilityPrivate;

  /// No description provided for @delete.
  ///
  /// In ko, this message translates to:
  /// **'삭제'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In ko, this message translates to:
  /// **'취소'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In ko, this message translates to:
  /// **'저장'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In ko, this message translates to:
  /// **'저장했어요'**
  String get saved;

  /// No description provided for @deleteRoomConfirm.
  ///
  /// In ko, this message translates to:
  /// **'이 전시실과 안의 작품이 모두 삭제됩니다. 계속할까요?'**
  String get deleteRoomConfirm;

  /// No description provided for @deleteArtworkConfirm.
  ///
  /// In ko, this message translates to:
  /// **'이 작품을 삭제할까요? 받은 평가와 감상평도 함께 지워집니다.'**
  String get deleteArtworkConfirm;

  /// No description provided for @dragToReorder.
  ///
  /// In ko, this message translates to:
  /// **'끌어서 순서를 바꾸면 방문자 화면에도 같은 순서로 걸립니다.'**
  String get dragToReorder;

  /// No description provided for @featured.
  ///
  /// In ko, this message translates to:
  /// **'대표 작품'**
  String get featured;

  /// No description provided for @editArtwork.
  ///
  /// In ko, this message translates to:
  /// **'작품 정보 수정'**
  String get editArtwork;

  /// No description provided for @uploadTitle.
  ///
  /// In ko, this message translates to:
  /// **'작품 올리기'**
  String get uploadTitle;

  /// No description provided for @pickPhotos.
  ///
  /// In ko, this message translates to:
  /// **'사진 선택'**
  String get pickPhotos;

  /// No description provided for @dropHere.
  ///
  /// In ko, this message translates to:
  /// **'여기로 사진을 끌어다 놓으세요'**
  String get dropHere;

  /// No description provided for @dropFormats.
  ///
  /// In ko, this message translates to:
  /// **'JPEG · PNG · HEIC · WebP, 한 장에 최대 50MB'**
  String get dropFormats;

  /// No description provided for @gpsRemoved.
  ///
  /// In ko, this message translates to:
  /// **'위치 정보(GPS)는 자동으로 지워져요'**
  String get gpsRemoved;

  /// No description provided for @title.
  ///
  /// In ko, this message translates to:
  /// **'제목'**
  String get title;

  /// No description provided for @titleEn.
  ///
  /// In ko, this message translates to:
  /// **'영어 제목 (선택)'**
  String get titleEn;

  /// No description provided for @year.
  ///
  /// In ko, this message translates to:
  /// **'제작연도'**
  String get year;

  /// No description provided for @size.
  ///
  /// In ko, this message translates to:
  /// **'크기'**
  String get size;

  /// No description provided for @medium.
  ///
  /// In ko, this message translates to:
  /// **'재료 · 기법'**
  String get medium;

  /// No description provided for @mediumWatercolor.
  ///
  /// In ko, this message translates to:
  /// **'수채화'**
  String get mediumWatercolor;

  /// No description provided for @mediumOil.
  ///
  /// In ko, this message translates to:
  /// **'유화'**
  String get mediumOil;

  /// No description provided for @mediumAcrylic.
  ///
  /// In ko, this message translates to:
  /// **'아크릴'**
  String get mediumAcrylic;

  /// No description provided for @mediumPhoto.
  ///
  /// In ko, this message translates to:
  /// **'사진'**
  String get mediumPhoto;

  /// No description provided for @mediumDigital.
  ///
  /// In ko, this message translates to:
  /// **'디지털'**
  String get mediumDigital;

  /// No description provided for @mediumOther.
  ///
  /// In ko, this message translates to:
  /// **'기타'**
  String get mediumOther;

  /// No description provided for @artistNote.
  ///
  /// In ko, this message translates to:
  /// **'작가 노트'**
  String get artistNote;

  /// No description provided for @artistNoteEn.
  ///
  /// In ko, this message translates to:
  /// **'영어 작가 노트 (선택)'**
  String get artistNoteEn;

  /// No description provided for @room.
  ///
  /// In ko, this message translates to:
  /// **'전시실'**
  String get room;

  /// No description provided for @watermark.
  ///
  /// In ko, this message translates to:
  /// **'작가명 워터마크 넣기'**
  String get watermark;

  /// No description provided for @acceptRatings.
  ///
  /// In ko, this message translates to:
  /// **'방문자 평가 받기'**
  String get acceptRatings;

  /// No description provided for @hangArtwork.
  ///
  /// In ko, this message translates to:
  /// **'전시실에 걸기'**
  String get hangArtwork;

  /// No description provided for @uploading.
  ///
  /// In ko, this message translates to:
  /// **'{total}장 중 {done}장 올리는 중'**
  String uploading(int done, int total);

  /// No description provided for @uploadDone.
  ///
  /// In ko, this message translates to:
  /// **'작품을 걸었어요'**
  String get uploadDone;

  /// No description provided for @fileTooLarge.
  ///
  /// In ko, this message translates to:
  /// **'50MB가 넘는 파일은 올릴 수 없어요'**
  String get fileTooLarge;

  /// No description provided for @unsupportedImage.
  ///
  /// In ko, this message translates to:
  /// **'열 수 없는 이미지예요'**
  String get unsupportedImage;

  /// No description provided for @quotaExceeded.
  ///
  /// In ko, this message translates to:
  /// **'무료 플랜은 작품 100점까지 올릴 수 있어요'**
  String get quotaExceeded;

  /// No description provided for @titleRequired.
  ///
  /// In ko, this message translates to:
  /// **'제목을 입력해 주세요'**
  String get titleRequired;

  /// No description provided for @needRoom.
  ///
  /// In ko, this message translates to:
  /// **'먼저 전시실을 만들어 주세요'**
  String get needRoom;

  /// No description provided for @reactionsTitle.
  ///
  /// In ko, this message translates to:
  /// **'반응'**
  String get reactionsTitle;

  /// No description provided for @visitorsThisWeek.
  ///
  /// In ko, this message translates to:
  /// **'이번 주 방문'**
  String get visitorsThisWeek;

  /// No description provided for @likes.
  ///
  /// In ko, this message translates to:
  /// **'공감'**
  String get likes;

  /// No description provided for @newComments.
  ///
  /// In ko, this message translates to:
  /// **'새 감상평'**
  String get newComments;

  /// No description provided for @pendingApproval.
  ///
  /// In ko, this message translates to:
  /// **'승인 대기'**
  String get pendingApproval;

  /// No description provided for @approve.
  ///
  /// In ko, this message translates to:
  /// **'승인'**
  String get approve;

  /// No description provided for @hide.
  ///
  /// In ko, this message translates to:
  /// **'숨기기'**
  String get hide;

  /// No description provided for @blockAuthor.
  ///
  /// In ko, this message translates to:
  /// **'작성자 차단'**
  String get blockAuthor;

  /// No description provided for @report.
  ///
  /// In ko, this message translates to:
  /// **'신고'**
  String get report;

  /// No description provided for @notifRating.
  ///
  /// In ko, this message translates to:
  /// **'새 평가 · {title}'**
  String notifRating(String title);

  /// No description provided for @notifComment.
  ///
  /// In ko, this message translates to:
  /// **'새 감상평 · {title}'**
  String notifComment(String title);

  /// No description provided for @notifGuestbook.
  ///
  /// In ko, this message translates to:
  /// **'방명록에 새 글'**
  String get notifGuestbook;

  /// No description provided for @notifPending.
  ///
  /// In ko, this message translates to:
  /// **'승인을 기다리는 감상평'**
  String get notifPending;

  /// No description provided for @noReactions.
  ///
  /// In ko, this message translates to:
  /// **'아직 반응이 없어요. 갤러리 링크를 공유해 보세요.'**
  String get noReactions;

  /// No description provided for @settingsTitle.
  ///
  /// In ko, this message translates to:
  /// **'설정'**
  String get settingsTitle;

  /// No description provided for @galleryInfo.
  ///
  /// In ko, this message translates to:
  /// **'갤러리 정보'**
  String get galleryInfo;

  /// No description provided for @bio.
  ///
  /// In ko, this message translates to:
  /// **'작가 소개'**
  String get bio;

  /// No description provided for @bioEn.
  ///
  /// In ko, this message translates to:
  /// **'영어 작가 소개 (선택)'**
  String get bioEn;

  /// No description provided for @ratingsOnGallery.
  ///
  /// In ko, this message translates to:
  /// **'방문자 평가 받기 (갤러리 전체)'**
  String get ratingsOnGallery;

  /// No description provided for @commentPolicy.
  ///
  /// In ko, this message translates to:
  /// **'감상평'**
  String get commentPolicy;

  /// No description provided for @policyOpen.
  ///
  /// In ko, this message translates to:
  /// **'바로 공개'**
  String get policyOpen;

  /// No description provided for @policyApprove.
  ///
  /// In ko, this message translates to:
  /// **'승인 후 공개'**
  String get policyApprove;

  /// No description provided for @policyOff.
  ///
  /// In ko, this message translates to:
  /// **'받지 않음'**
  String get policyOff;

  /// No description provided for @language.
  ///
  /// In ko, this message translates to:
  /// **'언어'**
  String get language;

  /// No description provided for @signOut.
  ///
  /// In ko, this message translates to:
  /// **'로그아웃'**
  String get signOut;

  /// No description provided for @planUsage.
  ///
  /// In ko, this message translates to:
  /// **'{plan} 플랜 · {count} / {limit}점'**
  String planUsage(String plan, int count, int limit);

  /// No description provided for @galleryStats.
  ///
  /// In ko, this message translates to:
  /// **'작품 {artworks} · 전시실 {rooms}'**
  String galleryStats(int artworks, int rooms);

  /// No description provided for @guestbook.
  ///
  /// In ko, this message translates to:
  /// **'방명록'**
  String get guestbook;

  /// No description provided for @writeGuestbook.
  ///
  /// In ko, this message translates to:
  /// **'방명록 남기기'**
  String get writeGuestbook;

  /// No description provided for @galleryNotFound.
  ///
  /// In ko, this message translates to:
  /// **'갤러리를 찾을 수 없어요'**
  String get galleryNotFound;

  /// No description provided for @like.
  ///
  /// In ko, this message translates to:
  /// **'공감'**
  String get like;

  /// No description provided for @comments.
  ///
  /// In ko, this message translates to:
  /// **'감상평'**
  String get comments;

  /// No description provided for @rateThis.
  ///
  /// In ko, this message translates to:
  /// **'이 작품 평가하기'**
  String get rateThis;

  /// No description provided for @composition.
  ///
  /// In ko, this message translates to:
  /// **'구도'**
  String get composition;

  /// No description provided for @color.
  ///
  /// In ko, this message translates to:
  /// **'색감'**
  String get color;

  /// No description provided for @technique.
  ///
  /// In ko, this message translates to:
  /// **'기술'**
  String get technique;

  /// No description provided for @emotion.
  ///
  /// In ko, this message translates to:
  /// **'감성'**
  String get emotion;

  /// No description provided for @submitRating.
  ///
  /// In ko, this message translates to:
  /// **'평가 남기기'**
  String get submitRating;

  /// No description provided for @updateRating.
  ///
  /// In ko, this message translates to:
  /// **'평가 수정하기'**
  String get updateRating;

  /// No description provided for @ratingSent.
  ///
  /// In ko, this message translates to:
  /// **'평가를 작가에게 전달했어요'**
  String get ratingSent;

  /// No description provided for @ratingNote.
  ///
  /// In ko, this message translates to:
  /// **'평가가 5건 이상 모이면 평균이 공개돼요. 작가에게는 바로 전달됩니다.'**
  String get ratingNote;

  /// No description provided for @ratingAverages.
  ///
  /// In ko, this message translates to:
  /// **'평균 평점 · {count}명 참여'**
  String ratingAverages(int count);

  /// No description provided for @signInToReact.
  ///
  /// In ko, this message translates to:
  /// **'로그인하면 평가와 감상평을 남길 수 있어요'**
  String get signInToReact;

  /// No description provided for @writeComment.
  ///
  /// In ko, this message translates to:
  /// **'감상평 남기기'**
  String get writeComment;

  /// No description provided for @commentPending.
  ///
  /// In ko, this message translates to:
  /// **'작가가 승인하면 공개돼요'**
  String get commentPending;

  /// No description provided for @commentsClosed.
  ///
  /// In ko, this message translates to:
  /// **'작가가 감상평을 받지 않고 있어요'**
  String get commentsClosed;

  /// No description provided for @ratingsOff.
  ///
  /// In ko, this message translates to:
  /// **'작가가 평가를 받지 않는 작품이에요'**
  String get ratingsOff;

  /// No description provided for @ownArtwork.
  ///
  /// In ko, this message translates to:
  /// **'내 작품은 평가할 수 없어요'**
  String get ownArtwork;

  /// No description provided for @starLabel.
  ///
  /// In ko, this message translates to:
  /// **'{criterion} {n}점'**
  String starLabel(String criterion, int n);

  /// No description provided for @send.
  ///
  /// In ko, this message translates to:
  /// **'보내기'**
  String get send;

  /// No description provided for @loadFailed.
  ///
  /// In ko, this message translates to:
  /// **'불러오지 못했어요. 다시 시도해 주세요.'**
  String get loadFailed;

  /// No description provided for @retry.
  ///
  /// In ko, this message translates to:
  /// **'다시 시도'**
  String get retry;

  /// No description provided for @somethingWrong.
  ///
  /// In ko, this message translates to:
  /// **'문제가 생겼어요. 잠시 후 다시 시도해 주세요.'**
  String get somethingWrong;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
