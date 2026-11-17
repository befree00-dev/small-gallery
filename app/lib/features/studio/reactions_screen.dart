import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../ui/common.dart';

/// What visitors said and did: comments to approve, ratings, guestbook entries.
class ReactionsScreen extends ConsumerStatefulWidget {
  const ReactionsScreen({super.key});

  @override
  ConsumerState<ReactionsScreen> createState() => _ReactionsScreenState();
}

class _ReactionsScreenState extends ConsumerState<ReactionsScreen> {
  @override
  void initState() {
    super.initState();
    // Opening this tab counts as reading the notifications.
    Future.microtask(() async {
      await ref.read(repositoryProvider).markNotificationsRead();
      ref.invalidate(notificationsProvider);
    });
  }

  Future<void> _refresh(String galleryId) async {
    ref.invalidate(summaryProvider(galleryId));
    ref.invalidate(notificationsProvider);
    ref.invalidate(moderationProvider(galleryId));
    await ref.read(moderationProvider(galleryId).future);
  }

  Future<void> _moderate(Gallery gallery, Comment c, CommentStatus status) async {
    try {
      await ref.read(repositoryProvider).setCommentStatus(c.id, status);
    } catch (e) {
      if (mounted) context.toast(errorText(context.l10n, e));
    }
    _refresh(gallery.id);
  }

  Future<void> _block(Gallery gallery, Comment c) async {
    final repo = ref.read(repositoryProvider);
    await repo.blockAuthor(gallery.id, c.authorId);
    await repo.setCommentStatus(c.id, CommentStatus.hidden);
    _refresh(gallery.id);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gallery = ref.watch(myGalleryProvider).value;
    if (gallery == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final summary = ref.watch(summaryProvider(gallery.id));
    final comments = ref.watch(moderationProvider(gallery.id));
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.reactionsTitle)),
      body: RefreshIndicator(
        onRefresh: () => _refresh(gallery.id),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  _Stat(label: l10n.visitorsThisWeek, value: summary.value?.viewsThisWeek),
                  _Stat(label: l10n.likes, value: summary.value?.totalLikes),
                  _Stat(label: l10n.pendingApproval, value: summary.value?.pendingComments),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            AsyncBody(
              value: comments,
              onRetry: () => ref.invalidate(moderationProvider(gallery.id)),
              builder: (list) => Column(children: [
                for (final c in list)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CommentCard(
                      comment: c,
                      onApprove: () => _moderate(gallery, c, CommentStatus.visible),
                      onHide: () => _moderate(gallery, c, CommentStatus.hidden),
                      onBlock: () => _block(gallery, c),
                    ),
                  ),
              ]),
            ),
            AsyncBody(
              value: notifications,
              builder: (list) {
                final ratings = list.where((n) => n.kind == NotificationKind.rating).toList();
                if (ratings.isEmpty && (comments.value?.isEmpty ?? false)) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Text(l10n.noReactions, style: const TextStyle(color: Palette.muted)),
                  );
                }
                return Column(children: [
                  for (final n in ratings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          leading: const Icon(Icons.star_outline, color: Palette.accent),
                          title: Text(_notificationText(l10n, n)),
                          subtitle: Text(_ago(context, n.createdAt), style: const TextStyle(color: Palette.muted)),
                        ),
                      ),
                    ),
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}

String _notificationText(AppLocalizations l10n, AppNotification n) => switch (n.kind) {
      NotificationKind.rating => l10n.notifRating(n.artworkTitle ?? ''),
      NotificationKind.comment => l10n.notifComment(n.artworkTitle ?? ''),
      NotificationKind.guestbook => l10n.notifGuestbook,
      NotificationKind.commentPending => l10n.notifPending,
    };

String _ago(BuildContext context, DateTime t) =>
    MaterialLocalizations.of(context).formatShortDate(t.toLocal());

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Palette.muted)),
        const SizedBox(height: 2),
        Text(value?.toString() ?? '–', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      ]);
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment, required this.onApprove, required this.onHide, required this.onBlock});

  final Comment comment;
  final VoidCallback onApprove;
  final VoidCallback onHide;
  final VoidCallback onBlock;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pending = comment.status == CommentStatus.pending;
    final where = comment.isGuestbook ? l10n.guestbook : (comment.artworkTitle ?? '');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      decoration: BoxDecoration(
        color: Palette.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pending ? const Color(0xFFC9D2EE) : Palette.line),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text.rich(
          TextSpan(children: [
            if (pending)
              TextSpan(
                text: '${l10n.pendingApproval} · ',
                style: const TextStyle(color: Palette.accent, fontWeight: FontWeight.w500),
              ),
            TextSpan(text: where),
          ]),
          style: const TextStyle(fontSize: 12, color: Palette.muted),
        ),
        const SizedBox(height: 6),
        Text.rich(TextSpan(children: [
          TextSpan(text: '${comment.authorName}  ', style: const TextStyle(fontWeight: FontWeight.w500)),
          TextSpan(text: comment.body),
        ]), style: const TextStyle(height: 1.6)),
        const SizedBox(height: 4),
        Row(children: [
          if (pending) FilledButton.tonal(onPressed: onApprove, child: Text(l10n.approve)),
          if (pending) const SizedBox(width: 8),
          TextButton(onPressed: onHide, child: Text(l10n.hide)),
          const Spacer(),
          TextButton(
            onPressed: onBlock,
            style: TextButton.styleFrom(foregroundColor: Palette.muted),
            child: Text(l10n.blockAuthor),
          ),
        ]),
      ]),
    );
  }
}
