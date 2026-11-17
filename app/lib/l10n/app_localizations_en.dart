// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Small Gallery';

  @override
  String get welcomeHeadline => 'Where everyone curates their own work';

  @override
  String get welcomeBody =>
      'Upload your work and your own small gallery opens right away.';

  @override
  String get signIn => 'Sign in';

  @override
  String get signUp => 'Create account';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get displayName => 'Name (artist name)';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get continueWithApple => 'Continue with Apple';

  @override
  String get haveAccount => 'I already have an account';

  @override
  String get needAccount => 'I\'m new here';

  @override
  String get visitByHandle => 'Visit a gallery by address';

  @override
  String get handleHint => 'e.g. jisu';

  @override
  String get go => 'Go';

  @override
  String get authFailed => 'Couldn\'t sign in. Check your email and password.';

  @override
  String get checkEmail =>
      'We sent you a confirmation email. Open its link, then sign in.';

  @override
  String get passwordRule => 'At least 8 characters';

  @override
  String get onboardingTitle => 'Open your gallery';

  @override
  String get stepField => 'What do you make?';

  @override
  String get fieldPainting => 'Painting';

  @override
  String get fieldPhoto => 'Photography';

  @override
  String get fieldIllustration => 'Illustration';

  @override
  String get fieldOther => 'Other';

  @override
  String get galleryTitle => 'Gallery name';

  @override
  String get galleryAddress => 'Gallery address';

  @override
  String get handleRule => '3–30 lowercase letters, digits or _';

  @override
  String get handleTaken => 'That address is already taken';

  @override
  String get theme => 'Theme';

  @override
  String get themeWhite => 'White cube';

  @override
  String get themeDark => 'Dark room';

  @override
  String get themeWood => 'Wood frame';

  @override
  String get firstRoomName => 'First room';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get openGallery => 'Open gallery';

  @override
  String get tabGallery => 'Gallery';

  @override
  String get tabUpload => 'Upload';

  @override
  String get tabReactions => 'Reactions';

  @override
  String get tabSettings => 'Settings';

  @override
  String get rooms => 'Rooms';

  @override
  String get newRoom => 'New room';

  @override
  String get roomTitle => 'Room name';

  @override
  String get roomStatement => 'Room statement';

  @override
  String artworksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count works',
      one: '1 work',
    );
    return '$_temp0';
  }

  @override
  String get viewAsVisitor => 'View as a visitor';

  @override
  String get shareGallery => 'Copy gallery link';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get emptyRoom => 'Nothing on the walls yet. Upload your first work.';

  @override
  String get emptyGallery => 'Create a room and hang your work.';

  @override
  String get visibility => 'Visibility';

  @override
  String get visibilityPublic => 'Public';

  @override
  String get visibilityUnlisted => 'Anyone with the link';

  @override
  String get visibilityPrivate => 'Private';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get deleteRoomConfirm =>
      'This deletes the room and every work in it. Continue?';

  @override
  String get deleteArtworkConfirm =>
      'Delete this work? Its ratings and comments are deleted too.';

  @override
  String get dragToReorder => 'Drag to reorder. Visitors see the same order.';

  @override
  String get featured => 'Featured';

  @override
  String get editArtwork => 'Edit work details';

  @override
  String get uploadTitle => 'Upload work';

  @override
  String get pickPhotos => 'Choose photos';

  @override
  String get dropHere => 'Drop photos here';

  @override
  String get dropFormats => 'JPEG · PNG · HEIC · WebP, up to 50 MB each';

  @override
  String get gpsRemoved => 'Location (GPS) data is removed automatically';

  @override
  String get title => 'Title';

  @override
  String get titleEn => 'English title (optional)';

  @override
  String get year => 'Year';

  @override
  String get size => 'Size';

  @override
  String get medium => 'Medium';

  @override
  String get mediumWatercolor => 'Watercolor';

  @override
  String get mediumOil => 'Oil';

  @override
  String get mediumAcrylic => 'Acrylic';

  @override
  String get mediumPhoto => 'Photograph';

  @override
  String get mediumDigital => 'Digital';

  @override
  String get mediumOther => 'Other';

  @override
  String get artistNote => 'Artist\'s note';

  @override
  String get artistNoteEn => 'English note (optional)';

  @override
  String get room => 'Room';

  @override
  String get watermark => 'Add name watermark';

  @override
  String get acceptRatings => 'Accept visitor ratings';

  @override
  String get hangArtwork => 'Hang in room';

  @override
  String uploading(int done, int total) {
    return 'Uploading $done of $total';
  }

  @override
  String get uploadDone => 'Your work is on the wall';

  @override
  String get fileTooLarge => 'Files over 50 MB can\'t be uploaded';

  @override
  String get unsupportedImage => 'This image can\'t be opened';

  @override
  String get quotaExceeded => 'The Free plan holds up to 100 works';

  @override
  String get titleRequired => 'Enter a title';

  @override
  String get needRoom => 'Create a room first';

  @override
  String get reactionsTitle => 'Reactions';

  @override
  String get visitorsThisWeek => 'Views this week';

  @override
  String get likes => 'Likes';

  @override
  String get newComments => 'New comments';

  @override
  String get pendingApproval => 'Awaiting approval';

  @override
  String get approve => 'Approve';

  @override
  String get hide => 'Hide';

  @override
  String get blockAuthor => 'Block author';

  @override
  String get report => 'Report';

  @override
  String notifRating(String title) {
    return 'New rating · $title';
  }

  @override
  String notifComment(String title) {
    return 'New comment · $title';
  }

  @override
  String get notifGuestbook => 'New guestbook entry';

  @override
  String get notifPending => 'A comment awaits approval';

  @override
  String get noReactions => 'No reactions yet. Try sharing your gallery link.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get galleryInfo => 'Gallery details';

  @override
  String get bio => 'About the artist';

  @override
  String get bioEn => 'About, in English (optional)';

  @override
  String get ratingsOnGallery => 'Accept visitor ratings (whole gallery)';

  @override
  String get commentPolicy => 'Comments';

  @override
  String get policyOpen => 'Publish right away';

  @override
  String get policyApprove => 'Publish after approval';

  @override
  String get policyOff => 'Off';

  @override
  String get language => 'Language';

  @override
  String get signOut => 'Sign out';

  @override
  String planUsage(String plan, int count, int limit) {
    return '$plan plan · $count / $limit works';
  }

  @override
  String galleryStats(int artworks, int rooms) {
    return '$artworks works · $rooms rooms';
  }

  @override
  String get guestbook => 'Guestbook';

  @override
  String get writeGuestbook => 'Sign the guestbook';

  @override
  String get galleryNotFound => 'Gallery not found';

  @override
  String get like => 'Like';

  @override
  String get comments => 'Comments';

  @override
  String get rateThis => 'Rate this work';

  @override
  String get composition => 'Composition';

  @override
  String get color => 'Color';

  @override
  String get technique => 'Technique';

  @override
  String get emotion => 'Feeling';

  @override
  String get submitRating => 'Send rating';

  @override
  String get updateRating => 'Update rating';

  @override
  String get ratingSent => 'Your rating went to the artist';

  @override
  String get ratingNote =>
      'Averages appear once 5 people have rated. The artist sees yours right away.';

  @override
  String ratingAverages(int count) {
    return 'Average · $count ratings';
  }

  @override
  String get signInToReact => 'Sign in to rate and comment';

  @override
  String get writeComment => 'Write a comment';

  @override
  String get commentPending => 'Visible once the artist approves it';

  @override
  String get commentsClosed => 'The artist isn\'t taking comments';

  @override
  String get ratingsOff => 'The artist isn\'t taking ratings for this work';

  @override
  String get ownArtwork => 'You can\'t rate your own work';

  @override
  String starLabel(String criterion, int n) {
    return '$criterion: $n stars';
  }

  @override
  String get send => 'Send';

  @override
  String get loadFailed => 'Couldn\'t load this. Please try again.';

  @override
  String get retry => 'Try again';

  @override
  String get somethingWrong =>
      'Something went wrong. Please try again shortly.';
}
