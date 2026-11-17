import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import 'image_pipeline.dart';
import 'models.dart';
import 'repository.dart';

class SupabaseGalleryRepository implements GalleryRepository {
  SupabaseGalleryRepository(this._client, this._prefs, {this.oauthRedirect});

  final SupabaseClient _client;
  final SharedPreferences _prefs;

  /// Deep link the OAuth flow returns to on mobile and desktop.
  final String? oauthRedirect;

  static const _deviceKeyPref = 'visitor_device_key';
  static const _uuid = Uuid();

  GoTrueClient get _auth => _client.auth;

  /// A random id this device keeps, so anonymous likes can be undone.
  String get _deviceKey {
    var key = _prefs.getString(_deviceKeyPref);
    if (key == null) {
      key = _uuid.v4();
      _prefs.setString(_deviceKeyPref, key);
    }
    return key;
  }

  String _requireUser() {
    final id = currentUserId;
    if (id == null) throw const AppException('not_signed_in');
    return id;
  }

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PostgrestException catch (e) {
      debugPrint('[supabase] database error ${e.code}: ${e.message} ${e.details ?? ''} ${e.hint ?? ''}');
      throw _map(e.code, e.message);
    } on StorageException catch (e) {
      debugPrint('[supabase] storage error ${e.statusCode}: ${e.message} ${e.error ?? ''}');
      throw _map(e.statusCode, e.message);
    } on AuthException catch (e) {
      debugPrint('[supabase] auth error ${e.statusCode}: ${e.message}');
      throw AppException('unknown:auth:${e.message}');
    } on AppException {
      rethrow;
    } catch (e, st) {
      debugPrint('[supabase] unexpected error: $e\n$st');
      rethrow;
    }
  }

  AppException _map(String? code, String message) {
    if (message.contains('handle_reserved')) return const AppException('handle_reserved');
    if (message.contains('artwork_quota_exceeded')) return const AppException('quota_exceeded');
    if (message.contains('comments_closed')) return const AppException('comments_closed');
    if (message.contains('author_blocked')) return const AppException('author_blocked');
    if (code == '23505' && message.contains('handle')) return const AppException('handle_taken');
    if (code == 'P0002' || code == '404') return const AppException('not_found');
    return AppException('unknown:$code:$message');
  }

  // Session ------------------------------------------------------------------

  @override
  String? get currentUserId => _auth.currentUser?.id;

  @override
  Stream<String?> get userChanges => _auth.onAuthStateChange.map((s) => s.session?.user.id);

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
    required String locale,
  }) async {
    final res = await _auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName, 'locale': locale},
    );
    return res.session != null;
  }

  @override
  Future<void> signInWithProvider(String provider) async {
    await _auth.signInWithOAuth(
      provider == 'apple' ? OAuthProvider.apple : OAuthProvider.google,
      redirectTo: oauthRedirect,
    );
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<Profile?> myProfile() => _guard(() async {
        final id = currentUserId;
        if (id == null) return null;
        final row = await _client.from('profiles').select().eq('id', id).maybeSingle();
        return row == null ? null : Profile.fromJson(row);
      });

  // Artist -----------------------------------------------------------------------

  @override
  Future<Gallery?> myGallery() => _guard(() async {
        final id = currentUserId;
        if (id == null) return null;
        final row = await _client
            .from('galleries')
            .select('*, profiles(display_name)')
            .eq('owner_id', id)
            .maybeSingle();
        return row == null ? null : Gallery.fromJson(row);
      });

  @override
  Future<bool> isHandleAvailable(String handle) => _guard(() async {
        if (!isValidHandle(handle)) return false;
        final reserved = await _client.from('reserved_handles').select('handle').eq('handle', handle).maybeSingle();
        if (reserved != null) return false;
        // A private gallery is invisible here; the insert's unique check still catches it.
        final taken = await _client.from('galleries').select('id').eq('handle', handle).maybeSingle();
        return taken == null;
      });

  @override
  Future<Gallery> createGallery({
    required String handle,
    required String title,
    required ArtField field,
    required GalleryTheme theme,
    required String firstRoomTitle,
  }) =>
      _guard(() async {
        final uid = _requireUser();
        final row = await _client
            .from('galleries')
            .insert({
              'owner_id': uid,
              'handle': handle,
              'title': title,
              'field': field.name,
              'theme': theme.name,
            })
            .select('*, profiles(display_name)')
            .single();
        final gallery = Gallery.fromJson(row);
        await createRoom(gallery.id, firstRoomTitle);
        return gallery;
      });

  @override
  Future<void> updateGallery(Gallery gallery) =>
      _guard(() => _client.from('galleries').update(gallery.toUpdateJson()).eq('id', gallery.id));

  @override
  Future<List<Room>> rooms(String galleryId) => _guard(() async {
        final rows = await _client
            .from('rooms')
            .select('*, artworks(count)')
            .eq('gallery_id', galleryId)
            .order('sort_order')
            .order('created_at');
        return rows.map(Room.fromJson).toList();
      });

  @override
  Future<Room> createRoom(String galleryId, String title) => _guard(() async {
        final existing = await rooms(galleryId);
        final row = await _client
            .from('rooms')
            .insert({'gallery_id': galleryId, 'title': title, 'sort_order': existing.length})
            .select()
            .single();
        return Room.fromJson(row);
      });

  @override
  Future<void> updateRoom(Room room) =>
      _guard(() => _client.from('rooms').update(room.toUpdateJson()).eq('id', room.id));

  @override
  Future<void> deleteRoom(String roomId) => _guard(() async {
        final works = await artworks(roomId);
        await _client.from('rooms').delete().eq('id', roomId);
        await _removeFiles(works);
      });

  @override
  Future<List<Artwork>> artworks(String roomId) => _guard(() async {
        final rows = await _client
            .from('artworks')
            .select()
            .eq('room_id', roomId)
            .order('sort_order')
            .order('created_at');
        return rows.map(Artwork.fromJson).toList();
      });

  @override
  Future<int> artworkCount(String galleryId) => _guard(() async {
        final res = await _client.from('artworks').select('id').eq('gallery_id', galleryId).count(CountOption.exact);
        return res.count;
      });

  @override
  Future<Artwork> uploadArtwork({
    required Gallery gallery,
    required ArtworkDraft draft,
    required Uint8List imageBytes,
  }) =>
      _guard(() async {
        final uid = _requireUser();
        final processed = await processImageInBackground(
          imageBytes,
          watermark: draft.watermark ? gallery.handle : null,
        );

        final id = _uuid.v4();
        final displayPath = '$uid/$id/display.jpg';
        final thumbPath = '$uid/$id/thumb.jpg';
        final originalPath = '$uid/$id/original';
        final bucket = _client.storage.from('artworks');
        const jpeg = FileOptions(contentType: 'image/jpeg', cacheControl: '31536000');

        await bucket.uploadBinary(displayPath, processed.display, fileOptions: jpeg);
        await bucket.uploadBinary(thumbPath, processed.thumbnail, fileOptions: jpeg);
        await _client.storage
            .from('originals')
            .uploadBinary(originalPath, imageBytes, fileOptions: FileOptions(contentType: sniffImageType(imageBytes)));

        try {
          final inRoom = await artworks(draft.roomId);
          final row = await _client
              .from('artworks')
              .insert({
                'id': id,
                'gallery_id': gallery.id,
                'room_id': draft.roomId,
                'title': draft.title.trim(),
                'title_en': _blankToNull(draft.titleEn),
                'year': draft.year,
                'medium': draft.medium,
                'size_text': draft.sizeText.trim(),
                'note': draft.note.trim(),
                'note_en': _blankToNull(draft.noteEn),
                'watermark': draft.watermark,
                'rating_enabled': draft.ratingEnabled,
                'sort_order': inRoom.length,
                'image_path': displayPath,
                'thumb_path': thumbPath,
                'width': processed.width,
                'height': processed.height,
                'exif': processed.exif,
              })
              .select()
              .single();
          return Artwork.fromJson(row);
        } catch (_) {
          await bucket.remove([displayPath, thumbPath]);
          await _client.storage.from('originals').remove([originalPath]);
          rethrow;
        }
      });

  @override
  Future<void> updateArtwork(Artwork artwork) =>
      _guard(() => _client.from('artworks').update(artwork.toUpdateJson()).eq('id', artwork.id));

  @override
  Future<void> reorderArtworks(List<Artwork> inOrder) => _guard(() async {
        for (var i = 0; i < inOrder.length; i++) {
          if (inOrder[i].sortOrder != i) {
            await _client.from('artworks').update({'sort_order': i}).eq('id', inOrder[i].id);
          }
        }
      });

  @override
  Future<void> deleteArtwork(Artwork artwork) => _guard(() async {
        await _client.from('artworks').delete().eq('id', artwork.id);
        await _removeFiles([artwork]);
      });

  Future<void> _removeFiles(List<Artwork> works) async {
    if (works.isEmpty) return;
    await _client.storage.from('artworks').remove([for (final a in works) ...[a.imagePath, a.thumbPath]]);
    await _client.storage
        .from('originals')
        .remove([for (final a in works) a.imagePath.replaceFirst('display.jpg', 'original')]);
  }

  @override
  Future<List<AppNotification>> notifications() => _guard(() async {
        final rows = await _client
            .from('notifications')
            .select('*, artworks(title)')
            .order('created_at', ascending: false)
            .limit(50);
        return rows.map(AppNotification.fromJson).toList();
      });

  @override
  Future<void> markNotificationsRead() => _guard(() async {
        await _client
            .from('notifications')
            .update({'read_at': DateTime.now().toUtc().toIso8601String()})
            .eq('recipient_id', _requireUser())
            .isFilter('read_at', null);
      });

  @override
  Future<List<Comment>> commentsForModeration(String galleryId) => _guard(() async {
        final rows = await _client
            .from('comments')
            .select('*, profiles(display_name), artworks(title)')
            .eq('gallery_id', galleryId)
            .neq('status', 'hidden')
            .order('created_at', ascending: false)
            .limit(50);
        return rows.map(Comment.fromJson).toList();
      });

  @override
  Future<void> setCommentStatus(String commentId, CommentStatus status) =>
      _guard(() => _client.from('comments').update({'status': status.name}).eq('id', commentId));

  @override
  Future<void> blockAuthor(String galleryId, String authorId) =>
      _guard(() => _client.from('blocked_authors').upsert({'gallery_id': galleryId, 'author_id': authorId}));

  @override
  Future<StudioSummary> studioSummary(String galleryId) => _guard(() async {
        final since = DateTime.now().toUtc().subtract(const Duration(days: 6));
        final day = '${since.year}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
        final views = await _client.from('view_stats').select('views').eq('gallery_id', galleryId).gte('day', day);
        final likes = await _client.from('artworks').select('like_count').eq('gallery_id', galleryId);
        final pending = await _client
            .from('comments')
            .select('id')
            .eq('gallery_id', galleryId)
            .eq('status', 'pending')
            .count(CountOption.exact);
        return StudioSummary(
          viewsThisWeek: views.fold<int>(0, (s, r) => s + (r['views'] as int)),
          totalLikes: likes.fold<int>(0, (s, r) => s + (r['like_count'] as int)),
          pendingComments: pending.count,
        );
      });

  // Visitor --------------------------------------------------------------------

  @override
  Future<Gallery?> galleryByHandle(String handle) => _guard(() async {
        final row = await _client
            .from('galleries')
            .select('*, profiles(display_name)')
            .eq('handle', normalizeHandle(handle))
            .maybeSingle();
        return row == null ? null : Gallery.fromJson(row);
      });

  @override
  Future<Artwork?> artwork(String artworkId) => _guard(() async {
        final row = await _client.from('artworks').select().eq('id', artworkId).maybeSingle();
        return row == null ? null : Artwork.fromJson(row);
      });

  @override
  Future<RatingStats?> ratingStats(String artworkId) => _guard(() async {
        final row = await _client.from('artwork_rating_stats').select().eq('artwork_id', artworkId).maybeSingle();
        return row == null ? null : RatingStats.fromJson(row);
      });

  @override
  Future<Rating?> myRating(String artworkId) => _guard(() async {
        final uid = currentUserId;
        if (uid == null) return null;
        final row =
            await _client.from('ratings').select().eq('artwork_id', artworkId).eq('user_id', uid).maybeSingle();
        return row == null ? null : Rating.fromJson(row);
      });

  @override
  Future<void> rate(String artworkId, Rating rating) => _guard(() async {
        await _client.from('ratings').upsert(
          {'artwork_id': artworkId, 'user_id': _requireUser(), ...rating.toJson()},
          onConflict: 'artwork_id,user_id',
        );
      });

  @override
  Future<bool> hasLiked(String artworkId) => _guard(() async {
        final res = await _client.rpc('has_liked', params: {'p_artwork_id': artworkId, 'p_device_key': _deviceKey});
        return res == true;
      });

  @override
  Future<LikeState> toggleLike(String artworkId) => _guard(() async {
        final res = await _client.rpc('toggle_like', params: {'p_artwork_id': artworkId, 'p_device_key': _deviceKey});
        final row = (res as List).first as Map<String, dynamic>;
        return LikeState(liked: row['liked'] as bool, count: row['like_count'] as int);
      });

  @override
  Future<List<Comment>> comments(String galleryId, {String? artworkId}) => _guard(() async {
        var query = _client.from('comments').select('*, profiles(display_name)').eq('gallery_id', galleryId);
        query = artworkId == null ? query.isFilter('artwork_id', null) : query.eq('artwork_id', artworkId);
        final uid = currentUserId;
        // Visitors see published comments plus their own that await approval.
        query = uid == null ? query.eq('status', 'visible') : query.or('status.eq.visible,author_id.eq.$uid');
        final rows = await query.order('created_at', ascending: false).limit(100);
        return rows.map(Comment.fromJson).toList();
      });

  @override
  Future<Comment> addComment({required String galleryId, String? artworkId, required String body}) =>
      _guard(() async {
        final row = await _client
            .from('comments')
            .insert({'gallery_id': galleryId, 'artwork_id': artworkId, 'author_id': _requireUser(), 'body': body})
            .select('*, profiles(display_name)')
            .single();
        return Comment.fromJson(row);
      });

  @override
  Future<void> report({required String targetType, required String targetId, required String reason}) =>
      _guard(() async {
        await _client.from('reports').upsert(
          {'target_type': targetType, 'target_id': targetId, 'reporter_id': _requireUser(), 'reason': reason},
          onConflict: 'target_type,target_id,reporter_id',
          ignoreDuplicates: true,
        );
      });

  @override
  Future<void> recordView(String galleryId, {String? artworkId}) => _guard(() async {
        await _client.rpc('record_view', params: {'p_gallery_id': galleryId, 'p_artwork_id': artworkId});
      });

  @override
  String imageUrl(String path) => _client.storage.from('artworks').getPublicUrl(path);
}

String? _blankToNull(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

/// Content type from the file's first bytes.
String sniffImageType(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return 'image/jpeg';
  if (b.length >= 8 && b[0] == 0x89 && b[1] == 0x50 && b[2] == 0x4E && b[3] == 0x47) return 'image/png';
  if (b.length >= 12 && String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') return 'image/webp';
  if (b.length >= 12 && String.fromCharCodes(b.sublist(4, 8)) == 'ftyp') return 'image/heic';
  return 'application/octet-stream';
}
