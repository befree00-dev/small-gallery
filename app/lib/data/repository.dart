import 'dart:typed_data';

import 'models.dart';

/// Everything the app reads and writes. Screens depend on this interface so
/// they can be tested with an in-memory fake (see test/fakes.dart).
abstract interface class GalleryRepository {
  // Session ------------------------------------------------------------------
  String? get currentUserId;
  Stream<String?> get userChanges;
  Future<void> signIn({required String email, required String password});

  /// Returns true when the account is ready, false when email confirmation is pending.
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
    required String locale,
  });
  Future<void> signInWithProvider(String provider);
  Future<void> signOut();
  Future<Profile?> myProfile();

  // Artist ---------------------------------------------------------------------
  Future<Gallery?> myGallery();
  Future<bool> isHandleAvailable(String handle);
  Future<Gallery> createGallery({
    required String handle,
    required String title,
    required ArtField field,
    required GalleryTheme theme,
    required String firstRoomTitle,
  });
  Future<void> updateGallery(Gallery gallery);

  Future<List<Room>> rooms(String galleryId);
  Future<Room> createRoom(String galleryId, String title);
  Future<void> updateRoom(Room room);
  Future<void> deleteRoom(String roomId);

  Future<List<Artwork>> artworks(String roomId);
  Future<int> artworkCount(String galleryId);
  Future<Artwork> uploadArtwork({required Gallery gallery, required ArtworkDraft draft, required Uint8List imageBytes});
  Future<void> updateArtwork(Artwork artwork);
  Future<void> reorderArtworks(List<Artwork> inOrder);
  Future<void> deleteArtwork(Artwork artwork);

  Future<List<AppNotification>> notifications();
  Future<void> markNotificationsRead();
  Future<List<Comment>> commentsForModeration(String galleryId);
  Future<void> setCommentStatus(String commentId, CommentStatus status);
  Future<void> blockAuthor(String galleryId, String authorId);
  Future<StudioSummary> studioSummary(String galleryId);

  // Visitor --------------------------------------------------------------------
  Future<Gallery?> galleryByHandle(String handle);
  Future<Artwork?> artwork(String artworkId);
  Future<RatingStats?> ratingStats(String artworkId);
  Future<Rating?> myRating(String artworkId);
  Future<void> rate(String artworkId, Rating rating);
  Future<bool> hasLiked(String artworkId);
  Future<LikeState> toggleLike(String artworkId);
  Future<List<Comment>> comments(String galleryId, {String? artworkId});
  Future<Comment> addComment({required String galleryId, String? artworkId, required String body});
  Future<void> report({required String targetType, required String targetId, required String reason});
  Future<void> recordView(String galleryId, {String? artworkId});

  /// Public URL of an image in the artworks bucket.
  String imageUrl(String path);
}
