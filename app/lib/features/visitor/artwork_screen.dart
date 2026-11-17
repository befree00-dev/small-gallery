import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../ui/common.dart';
import 'comments_section.dart';
import 'rating_panel.dart';

/// One work in the dark viewing room: zoomable image, details, like, rating, comments.
class ArtworkScreen extends ConsumerWidget {
  const ArtworkScreen({super.key, required this.handle, required this.artworkId});

  final String handle;
  final String artworkId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallery = ref.watch(galleryByHandleProvider(handle));
    final artwork = ref.watch(artworkProvider(artworkId));
    return Scaffold(
      backgroundColor: Palette.darkGround,
      appBar: AppBar(backgroundColor: Palette.darkGround, foregroundColor: Palette.darkInk),
      body: switch ((gallery, artwork)) {
        (AsyncData(value: final g?), AsyncData(value: final a?)) => _ArtworkView(gallery: g, artwork: a),
        (AsyncData(value: null), _) || (_, AsyncData(value: null)) => Center(
          child: Text(context.l10n.galleryNotFound, style: const TextStyle(color: Palette.darkInk)),
        ),
        (AsyncError(), _) || (_, AsyncError()) => AsyncBody(
          value: artwork,
          dark: true,
          builder: (_) => const SizedBox(),
          onRetry: () {
            ref.invalidate(galleryByHandleProvider(handle));
            ref.invalidate(artworkProvider(artworkId));
          },
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ArtworkView extends ConsumerStatefulWidget {
  const _ArtworkView({required this.gallery, required this.artwork});

  final Gallery gallery;
  final Artwork artwork;

  @override
  ConsumerState<_ArtworkView> createState() => _ArtworkViewState();
}

class _ArtworkViewState extends ConsumerState<_ArtworkView> {
  LikeState? _like;

  @override
  void initState() {
    super.initState();
    final repo = ref.read(repositoryProvider);
    repo.recordView(widget.gallery.id, artworkId: widget.artwork.id).ignore();
    repo.hasLiked(widget.artwork.id).then((liked) {
      if (mounted) setState(() => _like = LikeState(liked: liked, count: widget.artwork.likeCount));
    }).ignore();
  }

  Future<void> _toggleLike() async {
    final before = _like ?? LikeState(liked: false, count: widget.artwork.likeCount);
    // Optimistic: flip now, settle on the server's count.
    setState(() => _like = LikeState(liked: !before.liked, count: before.count + (before.liked ? -1 : 1)));
    try {
      final after = await ref.read(repositoryProvider).toggleLike(widget.artwork.id);
      if (mounted) setState(() => _like = after);
    } catch (e) {
      if (mounted) {
        setState(() => _like = before);
        context.toast(errorText(context.l10n, e));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = context.lang;
    final a = widget.artwork;
    final g = widget.gallery;
    final like = _like ?? LikeState(liked: false, count: a.likeCount);
    final details = [
      if (g.ownerName.isNotEmpty) g.ownerName,
      if (a.year != null) '${a.year}',
      if (a.medium.isNotEmpty) a.medium,
      if (a.sizeText.isNotEmpty) a.sizeText,
    ].join(' · ');
    final exif = [
      a.exif['camera'],
      a.exif['lens'],
      a.exif['focal'],
      a.exif['aperture'],
      a.exif['shutter'],
      if (a.exif['iso'] != null) 'ISO ${a.exif['iso']}',
    ].whereType<String>().join(' · ');
    final note = localized(a.note, a.noteEn, lang);

    final sequence = ref.watch(gallerySequenceProvider(g.id)).value;
    final works = sequence?.works ?? const <Artwork>[];
    final index = works.indexWhere((w) => w.id == a.id);
    final prev = index > 0 ? works[index - 1] : null;
    final next = index >= 0 && index < works.length - 1 ? works[index + 1] : null;
    final room = sequence?.roomOf[a.id];

    return CallbackShortcuts(
      // ← and → move between works. Text fields keep their own arrow keys.
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _goTo(prev),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () => _goTo(next),
      },
      child: Focus(
        autofocus: true,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: ListView(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
                      child: AspectRatio(
                        aspectRatio: a.aspectRatio,
                        child: InteractiveViewer(
                          maxScale: 4,
                          child: ArtworkImage(
                            path: a.imagePath,
                            semanticLabel: localized(a.title, a.titleEn, lang),
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 8,
                      child: _NavButton(icon: Icons.chevron_left, target: prev, label: l10n.prevWork, onGo: _goTo),
                    ),
                    Positioned(
                      right: 8,
                      child: _NavButton(icon: Icons.chevron_right, target: next, label: l10n.nextWork, onGo: _goTo),
                    ),
                  ],
                ),
                if (index >= 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      [
                        l10n.workPosition(index + 1, works.length),
                        if (room != null) localized(room.title, room.titleEn, lang),
                      ].join(' · '),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12, color: Palette.darkMuted),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localized(a.title, a.titleEn, lang),
                        style: serifTitle.copyWith(fontSize: 20, color: Palette.darkInk),
                      ),
                      const SizedBox(height: 6),
                      if (details.isNotEmpty)
                        Text(details, style: const TextStyle(fontSize: 12, color: Palette.darkMuted)),
                      if (exif.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(exif, style: const TextStyle(fontSize: 12, color: Palette.darkMuted)),
                      ],
                      if (note.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(note, style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFFD6D3CC))),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: _toggleLike,
                        style: TextButton.styleFrom(foregroundColor: Palette.darkInk, minimumSize: const Size(44, 44)),
                        icon: Icon(
                          like.liked ? Icons.favorite : Icons.favorite_border,
                          color: like.liked ? Palette.heart : Palette.darkInk,
                        ),
                        label: Text('${l10n.like} ${like.count}'),
                      ),
                      const SizedBox(width: 4),
                      Text('${l10n.comments} ${a.commentCount}', style: const TextStyle(color: Palette.darkInk)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                RatingPanel(gallery: g, artwork: a),
                Container(
                  color: Palette.darkSurface,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  child: CommentsSection(
                    gallery: g,
                    artworkId: a.id,
                    ink: Palette.darkInk,
                    muted: Palette.darkMuted,
                    card: const Color(0xFF2A2926),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _goTo(Artwork? target) {
    if (target == null) return;
    context.pushReplacement('/g/${widget.gallery.handle}/a/${target.id}');
  }
}

/// A round previous/next button over the image edge; disabled at either end.
class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.target, required this.label, required this.onGo});

  final IconData icon;
  final Artwork? target;
  final String Function(String title) label;
  final void Function(Artwork? target) onGo;

  @override
  Widget build(BuildContext context) {
    final t = target;
    return IconButton(
      tooltip: t == null ? null : label(localized(t.title, t.titleEn, context.lang)),
      onPressed: t == null ? null : () => onGo(t),
      style: IconButton.styleFrom(
        backgroundColor: const Color(0xB81F1E1C),
        foregroundColor: Palette.darkInk,
        disabledBackgroundColor: const Color(0x401F1E1C),
        disabledForegroundColor: const Color(0x66F2F1ED),
        minimumSize: const Size(44, 44),
      ),
      icon: Icon(icon),
    );
  }
}
