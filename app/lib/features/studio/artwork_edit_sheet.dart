import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../ui/common.dart';

/// Edits a hung work's details. Resolves to true when something changed.
Future<bool?> showArtworkEditSheet(BuildContext context, Artwork artwork, List<Room> rooms) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ArtworkEditSheet(artwork: artwork, rooms: rooms),
  );
}

class _ArtworkEditSheet extends ConsumerStatefulWidget {
  const _ArtworkEditSheet({required this.artwork, required this.rooms});

  final Artwork artwork;
  final List<Room> rooms;

  @override
  ConsumerState<_ArtworkEditSheet> createState() => _ArtworkEditSheetState();
}

class _ArtworkEditSheetState extends ConsumerState<_ArtworkEditSheet> {
  late final _title = TextEditingController(text: widget.artwork.title);
  late final _titleEn = TextEditingController(text: widget.artwork.titleEn ?? '');
  late final _year = TextEditingController(text: widget.artwork.year?.toString() ?? '');
  late final _size = TextEditingController(text: widget.artwork.sizeText);
  late final _note = TextEditingController(text: widget.artwork.note);
  late final _noteEn = TextEditingController(text: widget.artwork.noteEn ?? '');
  late Audience _visibility = widget.artwork.visibility;
  late bool _featured = widget.artwork.isFeatured;
  late bool _ratings = widget.artwork.ratingEnabled;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_title, _titleEn, _year, _size, _note, _noteEn]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_title.text.trim().isEmpty) {
      context.toast(l10n.titleRequired);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(repositoryProvider)
          .updateArtwork(
            widget.artwork.copyWith(
              title: _title.text.trim(),
              titleEn: _titleEn.text.trim(),
              year: int.tryParse(_year.text.trim()),
              sizeText: _size.text.trim(),
              note: _note.text.trim(),
              noteEn: _noteEn.text.trim(),
              visibility: _visibility,
              isFeatured: _featured,
              ratingEnabled: _ratings,
            ),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        context.toast(errorText(l10n, e));
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _delete() async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.deleteArtworkConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(repositoryProvider).deleteArtwork(widget.artwork);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.editArtwork, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 80,
              decoration: InputDecoration(labelText: l10n.title),
            ),
            TextField(
              controller: _titleEn,
              maxLength: 80,
              decoration: InputDecoration(labelText: l10n.titleEn),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _year,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.year),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _size,
                    decoration: InputDecoration(labelText: l10n.size),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(labelText: l10n.artistNote),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteEn,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(labelText: l10n.artistNoteEn),
            ),
            const SizedBox(height: 12),
            InnerVisibilityField(
              value: _visibility,
              parent: effectiveAudience([
                ref.watch(myGalleryProvider).value?.visibility ?? Audience.public,
                widget.rooms.where((r) => r.id == widget.artwork.roomId).firstOrNull?.visibility ?? Audience.public,
              ]),
              parentIsGallery: false,
              onChanged: (v) => setState(() => _visibility = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.featured),
              value: _featured,
              onChanged: (v) => setState(() => _featured = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.acceptRatings),
              value: _ratings,
              onChanged: (v) => setState(() => _ratings = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(onPressed: _busy ? null : _delete, child: Text(l10n.delete)),
                const Spacer(),
                FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
