/// Plain data types shared by the app. Field names follow the database columns
/// in supabase/migrations so mapping stays one-to-one.
library;

enum Audience {
  public,
  unlisted,
  private;

  static Audience parse(String? value) =>
      Audience.values.firstWhere((v) => v.name == value, orElse: () => Audience.public);
}

enum CommentPolicy {
  open,
  approve,
  off;

  static CommentPolicy parse(String? value) =>
      CommentPolicy.values.firstWhere((v) => v.name == value, orElse: () => CommentPolicy.approve);
}

enum GalleryTheme {
  white,
  dark,
  wood;

  static GalleryTheme parse(String? value) =>
      GalleryTheme.values.firstWhere((v) => v.name == value, orElse: () => GalleryTheme.white);
}

enum ArtField {
  painting,
  photo,
  illustration,
  other;

  static ArtField parse(String? value) =>
      ArtField.values.firstWhere((v) => v.name == value, orElse: () => ArtField.other);
}

/// Picks the English text when the viewer reads English and the artist wrote one.
String localized(String ko, String? en, String languageCode) =>
    languageCode == 'en' && en != null && en.trim().isNotEmpty ? en : ko;

final _handlePattern = RegExp(r'^[a-z0-9_]{3,30}$');

/// Mirrors the database check on galleries.handle.
bool isValidHandle(String handle) => _handlePattern.hasMatch(handle);

/// Normalizes what a person types as an address: "@Jisu ", "smallgallery.app/@jisu" → "jisu".
String normalizeHandle(String input) {
  var s = input.trim().toLowerCase();
  final at = s.lastIndexOf('@');
  if (at >= 0) s = s.substring(at + 1);
  final slash = s.lastIndexOf('/');
  if (slash >= 0) s = s.substring(slash + 1);
  return s;
}

class Profile {
  const Profile({required this.id, required this.displayName, required this.locale, required this.plan});

  final String id;
  final String displayName;
  final String locale;
  final String plan;

  int get artworkLimit => plan == 'plus' ? 2000 : 100;

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String,
    displayName: (j['display_name'] as String?) ?? '',
    locale: (j['locale'] as String?) ?? 'ko',
    plan: (j['plan'] as String?) ?? 'free',
  );
}

class Gallery {
  const Gallery({
    required this.id,
    required this.ownerId,
    required this.handle,
    required this.title,
    this.titleEn,
    this.bio = '',
    this.bioEn,
    this.field = ArtField.painting,
    this.theme = GalleryTheme.white,
    this.visibility = Audience.public,
    this.ratingEnabled = true,
    this.commentPolicy = CommentPolicy.approve,
    this.ownerName = '',
  });

  final String id;
  final String ownerId;
  final String handle;
  final String title;
  final String? titleEn;
  final String bio;
  final String? bioEn;
  final ArtField field;
  final GalleryTheme theme;
  final Audience visibility;
  final bool ratingEnabled;
  final CommentPolicy commentPolicy;
  final String ownerName;

  factory Gallery.fromJson(Map<String, dynamic> j) => Gallery(
    id: j['id'] as String,
    ownerId: j['owner_id'] as String,
    handle: j['handle'] as String,
    title: j['title'] as String,
    titleEn: j['title_en'] as String?,
    bio: (j['bio'] as String?) ?? '',
    bioEn: j['bio_en'] as String?,
    field: ArtField.parse(j['field'] as String?),
    theme: GalleryTheme.parse(j['theme'] as String?),
    visibility: Audience.parse(j['visibility'] as String?),
    ratingEnabled: (j['rating_enabled'] as bool?) ?? true,
    commentPolicy: CommentPolicy.parse(j['comment_policy'] as String?),
    ownerName: ((j['profiles'] as Map<String, dynamic>?)?['display_name'] as String?) ?? '',
  );

  /// Columns an artist may edit.
  Map<String, dynamic> toUpdateJson() => {
    'title': title,
    'title_en': _nullIfBlank(titleEn),
    'bio': bio,
    'bio_en': _nullIfBlank(bioEn),
    'field': field.name,
    'theme': theme.name,
    'visibility': visibility.name,
    'rating_enabled': ratingEnabled,
    'comment_policy': commentPolicy.name,
  };

  Gallery copyWith({
    String? title,
    String? titleEn,
    String? bio,
    String? bioEn,
    GalleryTheme? theme,
    Audience? visibility,
    bool? ratingEnabled,
    CommentPolicy? commentPolicy,
  }) => Gallery(
    id: id,
    ownerId: ownerId,
    handle: handle,
    title: title ?? this.title,
    titleEn: titleEn ?? this.titleEn,
    bio: bio ?? this.bio,
    bioEn: bioEn ?? this.bioEn,
    field: field,
    theme: theme ?? this.theme,
    visibility: visibility ?? this.visibility,
    ratingEnabled: ratingEnabled ?? this.ratingEnabled,
    commentPolicy: commentPolicy ?? this.commentPolicy,
    ownerName: ownerName,
  );
}

class Room {
  const Room({
    required this.id,
    required this.galleryId,
    required this.title,
    this.titleEn,
    this.statement = '',
    this.statementEn,
    this.sortOrder = 0,
    this.visibility = Audience.public,
    this.artworkCount = 0,
  });

  final String id;
  final String galleryId;
  final String title;
  final String? titleEn;
  final String statement;
  final String? statementEn;
  final int sortOrder;
  final Audience visibility;
  final int artworkCount;

  factory Room.fromJson(Map<String, dynamic> j) {
    final counts = j['artworks'];
    var count = 0;
    if (counts is List && counts.isNotEmpty && counts.first is Map) {
      count = ((counts.first as Map)['count'] as int?) ?? 0;
    }
    return Room(
      id: j['id'] as String,
      galleryId: j['gallery_id'] as String,
      title: j['title'] as String,
      titleEn: j['title_en'] as String?,
      statement: (j['statement'] as String?) ?? '',
      statementEn: j['statement_en'] as String?,
      sortOrder: (j['sort_order'] as int?) ?? 0,
      visibility: Audience.parse(j['visibility'] as String?),
      artworkCount: count,
    );
  }

  Map<String, dynamic> toUpdateJson() => {
    'title': title,
    'title_en': _nullIfBlank(titleEn),
    'statement': statement,
    'statement_en': _nullIfBlank(statementEn),
    'visibility': visibility.name,
    'sort_order': sortOrder,
  };

  Room copyWith({String? title, String? statement, Audience? visibility}) => Room(
    id: id,
    galleryId: galleryId,
    title: title ?? this.title,
    titleEn: titleEn,
    statement: statement ?? this.statement,
    statementEn: statementEn,
    sortOrder: sortOrder,
    visibility: visibility ?? this.visibility,
    artworkCount: artworkCount,
  );
}

class Artwork {
  const Artwork({
    required this.id,
    required this.galleryId,
    required this.roomId,
    required this.title,
    required this.imagePath,
    required this.thumbPath,
    required this.width,
    required this.height,
    this.titleEn,
    this.year,
    this.medium = '',
    this.sizeText = '',
    this.note = '',
    this.noteEn,
    this.sortOrder = 0,
    this.visibility = Audience.public,
    this.isFeatured = false,
    this.ratingEnabled = true,
    this.watermark = false,
    this.exif = const {},
    this.likeCount = 0,
    this.commentCount = 0,
  });

  final String id;
  final String galleryId;
  final String roomId;
  final String title;
  final String? titleEn;
  final int? year;
  final String medium;
  final String sizeText;
  final String note;
  final String? noteEn;
  final int sortOrder;
  final Audience visibility;
  final bool isFeatured;
  final bool ratingEnabled;
  final bool watermark;
  final String imagePath;
  final String thumbPath;
  final int width;
  final int height;
  final Map<String, dynamic> exif;
  final int likeCount;
  final int commentCount;

  double get aspectRatio => width / height;

  factory Artwork.fromJson(Map<String, dynamic> j) => Artwork(
    id: j['id'] as String,
    galleryId: j['gallery_id'] as String,
    roomId: j['room_id'] as String,
    title: j['title'] as String,
    titleEn: j['title_en'] as String?,
    year: j['year'] as int?,
    medium: (j['medium'] as String?) ?? '',
    sizeText: (j['size_text'] as String?) ?? '',
    note: (j['note'] as String?) ?? '',
    noteEn: j['note_en'] as String?,
    sortOrder: (j['sort_order'] as int?) ?? 0,
    visibility: Audience.parse(j['visibility'] as String?),
    isFeatured: (j['is_featured'] as bool?) ?? false,
    ratingEnabled: (j['rating_enabled'] as bool?) ?? true,
    watermark: (j['watermark'] as bool?) ?? false,
    imagePath: j['image_path'] as String,
    thumbPath: j['thumb_path'] as String,
    width: j['width'] as int,
    height: j['height'] as int,
    exif: (j['exif'] as Map<String, dynamic>?) ?? const {},
    likeCount: (j['like_count'] as int?) ?? 0,
    commentCount: (j['comment_count'] as int?) ?? 0,
  );

  Map<String, dynamic> toUpdateJson() => {
    'room_id': roomId,
    'title': title,
    'title_en': _nullIfBlank(titleEn),
    'year': year,
    'medium': medium,
    'size_text': sizeText,
    'note': note,
    'note_en': _nullIfBlank(noteEn),
    'visibility': visibility.name,
    'is_featured': isFeatured,
    'rating_enabled': ratingEnabled,
    'sort_order': sortOrder,
  };

  Artwork copyWith({
    String? title,
    String? titleEn,
    int? year,
    String? medium,
    String? sizeText,
    String? note,
    String? noteEn,
    int? sortOrder,
    Audience? visibility,
    bool? isFeatured,
    bool? ratingEnabled,
    int? likeCount,
  }) => Artwork(
    id: id,
    galleryId: galleryId,
    roomId: roomId,
    title: title ?? this.title,
    titleEn: titleEn ?? this.titleEn,
    year: year ?? this.year,
    medium: medium ?? this.medium,
    sizeText: sizeText ?? this.sizeText,
    note: note ?? this.note,
    noteEn: noteEn ?? this.noteEn,
    sortOrder: sortOrder ?? this.sortOrder,
    visibility: visibility ?? this.visibility,
    isFeatured: isFeatured ?? this.isFeatured,
    ratingEnabled: ratingEnabled ?? this.ratingEnabled,
    watermark: watermark,
    imagePath: imagePath,
    thumbPath: thumbPath,
    width: width,
    height: height,
    exif: exif,
    likeCount: likeCount ?? this.likeCount,
    commentCount: commentCount,
  );
}

/// One visitor's scores, 1–5 each.
class Rating {
  const Rating({required this.composition, required this.color, required this.technique, required this.emotion});

  final int composition;
  final int color;
  final int technique;
  final int emotion;

  factory Rating.fromJson(Map<String, dynamic> j) => Rating(
    composition: j['composition'] as int,
    color: j['color'] as int,
    technique: j['technique'] as int,
    emotion: j['emotion'] as int,
  );

  Map<String, dynamic> toJson() => {
    'composition': composition,
    'color': color,
    'technique': technique,
    'emotion': emotion,
  };
}

/// Averages. Visitors only receive these once 5 or more ratings exist.
class RatingStats {
  const RatingStats({
    required this.count,
    required this.composition,
    required this.color,
    required this.technique,
    required this.emotion,
  });

  final int count;
  final double composition;
  final double color;
  final double technique;
  final double emotion;

  static const publicThreshold = 5;

  factory RatingStats.fromJson(Map<String, dynamic> j) {
    double n(Object? v) => v == null ? 0 : (v is num ? v.toDouble() : double.parse(v.toString()));
    return RatingStats(
      count: j['rating_count'] as int,
      composition: n(j['avg_composition']),
      color: n(j['avg_color']),
      technique: n(j['avg_technique']),
      emotion: n(j['avg_emotion']),
    );
  }
}

enum CommentStatus {
  visible,
  pending,
  hidden;

  static CommentStatus parse(String? value) =>
      CommentStatus.values.firstWhere((v) => v.name == value, orElse: () => CommentStatus.pending);
}

class Comment {
  const Comment({
    required this.id,
    required this.galleryId,
    required this.authorId,
    required this.authorName,
    required this.body,
    required this.status,
    required this.createdAt,
    this.artworkId,
    this.artworkTitle,
  });

  final String id;
  final String galleryId;
  final String? artworkId;
  final String? artworkTitle;
  final String authorId;
  final String authorName;
  final String body;
  final CommentStatus status;
  final DateTime createdAt;

  bool get isGuestbook => artworkId == null;

  factory Comment.fromJson(Map<String, dynamic> j) => Comment(
    id: j['id'] as String,
    galleryId: j['gallery_id'] as String,
    artworkId: j['artwork_id'] as String?,
    artworkTitle: (j['artworks'] as Map<String, dynamic>?)?['title'] as String?,
    authorId: j['author_id'] as String,
    authorName: ((j['profiles'] as Map<String, dynamic>?)?['display_name'] as String?) ?? '',
    body: j['body'] as String,
    status: CommentStatus.parse(j['status'] as String?),
    createdAt: DateTime.parse(j['created_at'] as String),
  );
}

enum NotificationKind {
  comment,
  commentPending,
  rating,
  guestbook;

  static NotificationKind parse(String value) => switch (value) {
    'comment_pending' => NotificationKind.commentPending,
    'rating' => NotificationKind.rating,
    'guestbook' => NotificationKind.guestbook,
    _ => NotificationKind.comment,
  };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.createdAt,
    this.artworkId,
    this.artworkTitle,
    this.commentId,
    this.readAt,
  });

  final String id;
  final NotificationKind kind;
  final String? artworkId;
  final String? artworkTitle;
  final String? commentId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
    id: j['id'] as String,
    kind: NotificationKind.parse(j['kind'] as String),
    artworkId: j['artwork_id'] as String?,
    artworkTitle: (j['artworks'] as Map<String, dynamic>?)?['title'] as String?,
    commentId: j['comment_id'] as String?,
    createdAt: DateTime.parse(j['created_at'] as String),
    readAt: j['read_at'] == null ? null : DateTime.parse(j['read_at'] as String),
  );
}

class StudioSummary {
  const StudioSummary({required this.viewsThisWeek, required this.totalLikes, required this.pendingComments});

  final int viewsThisWeek;
  final int totalLikes;
  final int pendingComments;
}

class LikeState {
  const LikeState({required this.liked, required this.count});

  final bool liked;
  final int count;
}

/// What the artist filled in on the upload screen, before the image is processed.
class ArtworkDraft {
  const ArtworkDraft({
    required this.roomId,
    required this.title,
    this.titleEn,
    this.year,
    this.medium = '',
    this.sizeText = '',
    this.note = '',
    this.noteEn,
    this.watermark = false,
    this.ratingEnabled = true,
  });

  final String roomId;
  final String title;
  final String? titleEn;
  final int? year;
  final String medium;
  final String sizeText;
  final String note;
  final String? noteEn;
  final bool watermark;
  final bool ratingEnabled;
}

class AppException implements Exception {
  const AppException(this.code);

  /// handle_taken · handle_reserved · quota_exceeded · comments_closed ·
  /// author_blocked · file_too_large · unsupported_image · not_found · unknown
  final String code;

  @override
  String toString() => 'AppException($code)';
}

String? _nullIfBlank(String? s) => s == null || s.trim().isEmpty ? null : s.trim();
