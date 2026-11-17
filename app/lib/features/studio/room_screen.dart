import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../ui/common.dart';
import 'artwork_edit_sheet.dart';

/// One room: its name, statement and visibility, and the order its works hang in.
class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  final _title = TextEditingController();
  final _statement = TextEditingController();
  Audience _visibility = Audience.public;
  Room? _room;
  List<Artwork>? _order;

  @override
  void dispose() {
    _title.dispose();
    _statement.dispose();
    super.dispose();
  }

  void _load(Room room) {
    if (_room?.id == room.id) return;
    _room = room;
    _title.text = room.title;
    _statement.text = room.statement;
    _visibility = room.visibility;
  }

  Future<void> _save(Gallery gallery) async {
    final l10n = context.l10n;
    final room = _room!;
    if (_title.text.trim().isEmpty) return;
    try {
      await ref
          .read(repositoryProvider)
          .updateRoom(
            room.copyWith(title: _title.text.trim(), statement: _statement.text.trim(), visibility: _visibility),
          );
      ref.invalidate(roomsProvider(gallery.id));
      if (mounted) context.toast(l10n.saved);
    } catch (e) {
      if (mounted) context.toast(errorText(l10n, e));
    }
  }

  Future<void> _delete(Gallery gallery) async {
    final l10n = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l10n.deleteRoomConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(repositoryProvider).deleteRoom(widget.roomId);
    ref.invalidate(roomsProvider(gallery.id));
    if (mounted) context.pop();
  }

  Future<void> _reorder(int from, int to) async {
    final list = [..._order!];
    list.insert(to, list.removeAt(from));
    setState(() => _order = list);
    try {
      await ref.read(repositoryProvider).reorderArtworks(list);
      ref.invalidate(artworksProvider(widget.roomId));
    } catch (e) {
      if (mounted) context.toast(errorText(context.l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gallery = ref.watch(myGalleryProvider).value;
    if (gallery == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final rooms = ref.watch(roomsProvider(gallery.id)).value ?? const <Room>[];
    final room = rooms.where((r) => r.id == widget.roomId).firstOrNull;
    if (room != null) _load(room);
    final works = ref.watch(artworksProvider(widget.roomId));
    works.whenData((w) => _order = _order?.length == w.length ? _order : w);

    return Scaffold(
      appBar: AppBar(
        title: Text(room?.title ?? ''),
        actions: [
          IconButton(tooltip: l10n.delete, icon: const Icon(Icons.delete_outline), onPressed: () => _delete(gallery)),
          FilledButton(onPressed: room == null ? null : () => _save(gallery), child: Text(l10n.save)),
          const SizedBox(width: 12),
        ],
      ),
      body: room == null
          ? const Center(child: CircularProgressIndicator())
          : AsyncBody(
              value: works,
              onRetry: () => ref.invalidate(artworksProvider(widget.roomId)),
              builder: (_) => ReorderableListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                header: _header(l10n),
                onReorderItem: _reorder,
                children: [
                  for (final a in _order!)
                    Padding(
                      key: ValueKey(a.id),
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.fromLTRB(8, 4, 40, 4),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: SizedBox.square(
                              dimension: 56,
                              child: ArtworkImage(path: a.thumbPath, semanticLabel: a.title),
                            ),
                          ),
                          title: Text(a.title),
                          subtitle: Text(
                            [
                              if (a.isFeatured) l10n.featured,
                              visibilityLabel(l10n, a.visibility),
                              '♡ ${a.likeCount}',
                            ].join(' · '),
                            style: const TextStyle(color: Palette.muted, fontSize: 12),
                          ),
                          onTap: () async {
                            final changed = await showArtworkEditSheet(context, a, rooms);
                            if (changed == true) {
                              _order = null;
                              ref.invalidate(artworksProvider(widget.roomId));
                              ref.invalidate(roomsProvider(gallery.id));
                            }
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _header(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            maxLength: 60,
            decoration: InputDecoration(labelText: l10n.roomTitle),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _statement,
            minLines: 2,
            maxLines: 5,
            maxLength: 1000,
            decoration: InputDecoration(labelText: l10n.roomStatement),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Audience>(
            initialValue: _visibility,
            decoration: InputDecoration(labelText: l10n.visibility),
            items: [for (final v in Audience.values) DropdownMenuItem(value: v, child: Text(visibilityLabel(l10n, v)))],
            onChanged: (v) => setState(() => _visibility = v!),
          ),
          const SizedBox(height: 20),
          if ((_order ?? const []).isEmpty)
            Text(l10n.emptyRoom, style: const TextStyle(color: Palette.muted))
          else
            Text(l10n.dragToReorder, style: const TextStyle(color: Palette.muted, fontSize: 12)),
        ],
      ),
    );
  }
}
