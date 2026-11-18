import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../ui/common.dart';

/// "내 갤러리": the gallery's address, its rooms, and a way in to each.
class StudioHomeScreen extends ConsumerWidget {
  const StudioHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gallery = ref.watch(myGalleryProvider).value;
    if (gallery == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final rooms = ref.watch(roomsProvider(gallery.id));
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(gallery.title, style: serifTitle.copyWith(fontSize: 20)),
        actions: [
          IconButton(
            tooltip: l10n.shareGallery,
            icon: const Icon(Icons.link),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: publicGalleryUrl(gallery.handle)));
              if (context.mounted) context.toast(l10n.linkCopied);
            },
          ),
          TextButton(onPressed: () => context.push('/g/${gallery.handle}'), child: Text(l10n.viewAsVisitor)),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newRoom(context, ref, gallery),
        icon: const Icon(Icons.add),
        label: Text(l10n.newRoom),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(roomsProvider(gallery.id).future),
        child: AsyncBody(
          value: rooms,
          onRetry: () => ref.invalidate(roomsProvider(gallery.id)),
          builder: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 96),
            children: [
              Text('$siteHost/@${gallery.handle}', style: const TextStyle(color: Palette.muted, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                '${l10n.visibility}: ${visibilityLabel(l10n, gallery.visibility)}',
                style: const TextStyle(color: Palette.muted, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.galleryStats(list.fold(0, (s, r) => s + r.artworkCount), list.length),
                style: const TextStyle(color: Palette.muted, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Text(l10n.rooms, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 8),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(l10n.emptyGallery, style: const TextStyle(color: Palette.muted)),
                ),
              for (final room in list)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      title: Text(room.title, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(
                        '${l10n.artworksCount(room.artworkCount)} · ${visibilityLabel(l10n, effectiveAudience([gallery.visibility, room.visibility]))}',
                        style: const TextStyle(color: Palette.muted),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/studio/rooms/${room.id}'),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _newRoom(BuildContext context, WidgetRef ref, Gallery gallery) async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.newRoom),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(labelText: l10n.roomTitle),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: Text(l10n.save)),
        ],
      ),
    );
    controller.dispose();
    if (title == null || title.trim().isEmpty) return;
    try {
      await ref.read(repositoryProvider).createRoom(gallery.id, title.trim());
      ref.invalidate(roomsProvider(gallery.id));
    } catch (e) {
      if (context.mounted) context.toast(errorText(l10n, e));
    }
  }
}
