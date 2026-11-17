import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../ui/common.dart';

/// Comments on an artwork, or the gallery guestbook when [artworkId] is null.
class CommentsSection extends ConsumerStatefulWidget {
  const CommentsSection({
    super.key,
    required this.gallery,
    this.artworkId,
    required this.ink,
    required this.muted,
    required this.card,
  });

  final Gallery gallery;
  final String? artworkId;
  final Color ink;
  final Color muted;
  final Color card;

  @override
  ConsumerState<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<CommentsSection> {
  final _body = TextEditingController();
  bool _busy = false;

  ({String galleryId, String? artworkId}) get _key => (galleryId: widget.gallery.id, artworkId: widget.artworkId);

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = context.l10n;
    final text = _body.text.trim();
    if (text.isEmpty) return;
    setState(() => _busy = true);
    try {
      final c = await ref
          .read(repositoryProvider)
          .addComment(galleryId: widget.gallery.id, artworkId: widget.artworkId, body: text);
      _body.clear();
      ref.invalidate(commentsProvider(_key));
      if (mounted && c.status == CommentStatus.pending) context.toast(l10n.commentPending);
    } catch (e) {
      if (mounted) context.toast(errorText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _report(Comment c) async {
    await ref.read(repositoryProvider).report(targetType: 'comment', targetId: c.id, reason: 'abuse');
    if (mounted) context.toast(context.l10n.saved);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uid = ref.watch(userIdProvider).value;
    final comments = ref.watch(commentsProvider(_key));
    final closed = widget.gallery.commentPolicy == CommentPolicy.off;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(
        widget.artworkId == null ? l10n.guestbook : l10n.comments,
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: widget.ink),
      ),
      const SizedBox(height: 10),
      if (closed)
        Text(l10n.commentsClosed, style: TextStyle(color: widget.muted, fontSize: 13))
      else if (uid == null)
        Row(children: [
          Expanded(child: Text(l10n.signInToReact, style: TextStyle(color: widget.muted, fontSize: 13))),
          TextButton(onPressed: () => context.push('/welcome'), child: Text(l10n.signIn)),
        ])
      else
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: TextField(
              controller: _body,
              minLines: 1,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: widget.artworkId == null ? l10n.writeGuestbook : l10n.writeComment,
                counterText: '',
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(onPressed: _busy ? null : _send, child: Text(l10n.send)),
        ]),
      const SizedBox(height: 12),
      comments.when(
        loading: () => const SizedBox(height: 40),
        error: (e, _) => Text(l10n.loadFailed, style: TextStyle(color: widget.muted)),
        data: (list) => Column(children: [
          for (final c in list)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(14, 12, 4, 8),
              decoration: BoxDecoration(color: widget.card, borderRadius: BorderRadius.circular(10)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      c.status == CommentStatus.pending ? '${c.authorName} · ${l10n.commentPending}' : c.authorName,
                      style: TextStyle(fontSize: 12, color: widget.muted, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(c.body, style: TextStyle(color: widget.ink, height: 1.6)),
                  ]),
                ),
                if (uid != null && uid != c.authorId)
                  IconButton(
                    tooltip: l10n.report,
                    icon: Icon(Icons.flag_outlined, size: 18, color: widget.muted),
                    onPressed: () => _report(c),
                  ),
              ]),
            ),
        ]),
      ),
    ]);
  }
}
