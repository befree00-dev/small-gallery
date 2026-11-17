import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models.dart';
import '../data/repository.dart';

/// Overridden in main() (Supabase) and in tests (in-memory fake).
final repositoryProvider = Provider<GalleryRepository>((ref) => throw UnimplementedError('repositoryProvider'));
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('prefsProvider'));

final userIdProvider = StreamProvider<String?>((ref) async* {
  final repo = ref.watch(repositoryProvider);
  yield repo.currentUserId;
  yield* repo.userChanges;
});

/// The signed-in artist's gallery, or null before onboarding.
final myGalleryProvider = FutureProvider<Gallery?>((ref) async {
  final uid = await ref.watch(userIdProvider.future);
  if (uid == null) return null;
  return ref.watch(repositoryProvider).myGallery();
});

final myProfileProvider = FutureProvider<Profile?>((ref) async {
  await ref.watch(userIdProvider.future);
  return ref.watch(repositoryProvider).myProfile();
});

final roomsProvider = FutureProvider.family<List<Room>, String>(
  (ref, galleryId) => ref.watch(repositoryProvider).rooms(galleryId),
);

final artworksProvider = FutureProvider.family<List<Artwork>, String>(
  (ref, roomId) => ref.watch(repositoryProvider).artworks(roomId),
);

final artworkCountProvider = FutureProvider.family<int, String>(
  (ref, galleryId) => ref.watch(repositoryProvider).artworkCount(galleryId),
);

final notificationsProvider = FutureProvider<List<AppNotification>>(
  (ref) => ref.watch(repositoryProvider).notifications(),
);

final moderationProvider = FutureProvider.family<List<Comment>, String>(
  (ref, galleryId) => ref.watch(repositoryProvider).commentsForModeration(galleryId),
);

final summaryProvider = FutureProvider.family<StudioSummary, String>(
  (ref, galleryId) => ref.watch(repositoryProvider).studioSummary(galleryId),
);

final galleryByHandleProvider = FutureProvider.family<Gallery?, String>(
  (ref, handle) => ref.watch(repositoryProvider).galleryByHandle(handle),
);

final artworkProvider = FutureProvider.family<Artwork?, String>(
  (ref, id) => ref.watch(repositoryProvider).artwork(id),
);

final ratingStatsProvider = FutureProvider.family<RatingStats?, String>(
  (ref, artworkId) => ref.watch(repositoryProvider).ratingStats(artworkId),
);

final myRatingProvider = FutureProvider.family<Rating?, String>((ref, artworkId) async {
  await ref.watch(userIdProvider.future);
  return ref.watch(repositoryProvider).myRating(artworkId);
});

final commentsProvider = FutureProvider.family<List<Comment>, ({String galleryId, String? artworkId})>(
  (ref, key) => ref.watch(repositoryProvider).comments(key.galleryId, artworkId: key.artworkId),
);

/// App language: the saved choice, else the device language when it is English, else Korean.
class LocaleController extends Notifier<Locale> {
  static const _key = 'app_locale';
  static const supported = [Locale('ko'), Locale('en')];

  @override
  Locale build() {
    final saved = ref.watch(prefsProvider).getString(_key);
    if (saved != null) return Locale(saved);
    final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return Locale(device == 'en' ? 'en' : 'ko');
  }

  void set(Locale locale) {
    ref.read(prefsProvider).setString(_key, locale.languageCode);
    state = locale;
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale>(LocaleController.new);
