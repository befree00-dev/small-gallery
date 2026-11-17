import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:small_gallery/data/models.dart';
import 'package:small_gallery/data/repository.dart';
import 'package:small_gallery/l10n/app_localizations.dart';
import 'package:small_gallery/state/providers.dart';
import 'package:small_gallery/theme.dart';

const artistId = 'artist-1';
const visitorId = 'visitor-1';

const testGallery = Gallery(id: 'g1', ownerId: artistId, handle: 'jisu', title: '지수의 작은 정원', ownerName: '김지수');

const testRoom = Room(id: 'r1', galleryId: 'g1', title: '봄의 산책', artworkCount: 1);

const testArtwork = Artwork(
  id: 'a1',
  galleryId: 'g1',
  roomId: 'r1',
  title: '4월, 개천 옆 벚나무',
  imagePath: 'artist-1/a1/display.jpg',
  thumbPath: 'artist-1/a1/thumb.jpg',
  width: 1600,
  height: 2000,
  likeCount: 128,
);

/// In-memory stand-in for Supabase. Records what screens ask it to do.
class FakeRepository implements GalleryRepository {
  FakeRepository({String? userId, this.gallery = testGallery, this.stats})
    : _userId = userId; // ignore: prefer_initializing_formals

  String? _userId;
  final _users = StreamController<String?>.broadcast();
  Gallery? gallery;
  RatingStats? stats;
  Rating? existingRating;
  final rooms_ = <Room>[testRoom];
  final artworks_ = <Artwork>[testArtwork];

  final ratings = <(String, Rating)>[];
  final uploads = <ArtworkDraft>[];
  final createdGalleries = <String>[];
  final takenHandles = <String>{'taken'};
  Object? uploadError;

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> get userChanges => _users.stream;

  void signInAs(String? id) {
    _userId = id;
    _users.add(id);
  }

  @override
  Future<void> signIn({required String email, required String password}) async => signInAs(visitorId);

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
    required String locale,
  }) async {
    signInAs(visitorId);
    return true;
  }

  @override
  Future<void> signInWithProvider(String provider) async {}

  @override
  Future<void> signOut() async => signInAs(null);

  @override
  Future<Profile?> myProfile() async =>
      _userId == null ? null : Profile(id: _userId!, displayName: 'Tester', locale: 'ko', plan: 'free');

  @override
  Future<Gallery?> myGallery() async => _userId == artistId ? gallery : null;

  @override
  Future<bool> isHandleAvailable(String handle) async => isValidHandle(handle) && !takenHandles.contains(handle);

  @override
  Future<Gallery> createGallery({
    required String handle,
    required String title,
    required ArtField field,
    required GalleryTheme theme,
    required String firstRoomTitle,
  }) async {
    createdGalleries.add(handle);
    gallery = Gallery(id: 'g-new', ownerId: _userId!, handle: handle, title: title, field: field, theme: theme);
    return gallery!;
  }

  @override
  Future<void> updateGallery(Gallery g) async => gallery = g;

  @override
  Future<List<Room>> rooms(String galleryId) async => rooms_;

  @override
  Future<Room> createRoom(String galleryId, String title) async {
    final r = Room(id: 'r${rooms_.length + 1}', galleryId: galleryId, title: title);
    rooms_.add(r);
    return r;
  }

  @override
  Future<void> updateRoom(Room room) async {}

  @override
  Future<void> deleteRoom(String roomId) async => rooms_.removeWhere((r) => r.id == roomId);

  @override
  Future<List<Artwork>> artworks(String roomId) async => artworks_.where((a) => a.roomId == roomId).toList();

  @override
  Future<int> artworkCount(String galleryId) async => artworks_.length;

  @override
  Future<Artwork> uploadArtwork({
    required Gallery gallery,
    required ArtworkDraft draft,
    required Uint8List imageBytes,
  }) async {
    if (uploadError != null) throw uploadError!;
    uploads.add(draft);
    return testArtwork;
  }

  @override
  Future<void> updateArtwork(Artwork artwork) async {}

  @override
  Future<void> reorderArtworks(List<Artwork> inOrder) async {}

  @override
  Future<void> deleteArtwork(Artwork artwork) async {}

  @override
  Future<List<AppNotification>> notifications() async => const [];

  @override
  Future<void> markNotificationsRead() async {}

  @override
  Future<List<Comment>> commentsForModeration(String galleryId) async => const [];

  @override
  Future<void> setCommentStatus(String commentId, CommentStatus status) async {}

  @override
  Future<void> blockAuthor(String galleryId, String authorId) async {}

  @override
  Future<StudioSummary> studioSummary(String galleryId) async =>
      const StudioSummary(viewsThisWeek: 86, totalLikes: 214, pendingComments: 1);

  @override
  Future<Gallery?> galleryByHandle(String handle) async => handle == gallery?.handle ? gallery : null;

  @override
  Future<Artwork?> artwork(String artworkId) async => artworks_.where((a) => a.id == artworkId).firstOrNull;

  @override
  Future<RatingStats?> ratingStats(String artworkId) async => stats;

  @override
  Future<Rating?> myRating(String artworkId) async => existingRating;

  @override
  Future<void> rate(String artworkId, Rating rating) async => ratings.add((artworkId, rating));

  @override
  Future<bool> hasLiked(String artworkId) async => false;

  @override
  Future<LikeState> toggleLike(String artworkId) async => const LikeState(liked: true, count: 129);

  @override
  Future<List<Comment>> comments(String galleryId, {String? artworkId}) async => const [];

  @override
  Future<Comment> addComment({required String galleryId, String? artworkId, required String body}) async => Comment(
    id: 'c1',
    galleryId: galleryId,
    artworkId: artworkId,
    authorId: _userId!,
    authorName: 'Tester',
    body: body,
    status: CommentStatus.pending,
    createdAt: DateTime(2026),
  );

  @override
  Future<void> report({required String targetType, required String targetId, required String reason}) async {}

  @override
  Future<void> recordView(String galleryId, {String? artworkId}) async {}

  @override
  String imageUrl(String path) => 'https://example.invalid/$path';
}

/// Pumps [child] inside the app's theme, localizations and providers.
Future<void> pumpWithApp(
  WidgetTester tester,
  Widget child, {
  required FakeRepository repo,
  Locale locale = const Locale('ko'),
  List overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({'app_locale': locale.languageCode});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        repositoryProvider.overrideWithValue(repo),
        prefsProvider.overrideWithValue(prefs),
        ...overrides.cast(),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp(
          theme: buildTheme(),
          locale: ref.watch(localeProvider),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
          home: child,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
