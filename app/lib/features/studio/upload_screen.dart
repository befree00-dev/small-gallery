import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/image_pipeline.dart' show maxUploadBytes;
import '../../data/models.dart';
import '../../l10n/app_localizations.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../ui/common.dart';

/// Opens the platform photo picker. Overridden in tests.
final pickImagesProvider = Provider<Future<List<XFile>> Function()>(
  (ref) =>
      () => ImagePicker().pickMultiImage(),
);

/// Desktop drag-and-drop needs a native window; tests and mobile skip it.
final enableDropTargetProvider = Provider<bool>(
  (ref) =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS),
);

/// One picked photo and the details written for it.
class _Pending {
  _Pending(this.name, this.bytes) : title = TextEditingController(text: _titleFromName(name));

  final String name;
  final Uint8List bytes;
  final TextEditingController title;
  final titleEn = TextEditingController();
  final note = TextEditingController();
  final noteEn = TextEditingController();
  final size = TextEditingController();

  void dispose() {
    for (final c in [title, titleEn, note, noteEn, size]) {
      c.dispose();
    }
  }

  /// Camera file names (IMG_1234, DSC01234, PXL_…) make poor titles.
  static String _titleFromName(String name) {
    final stem = name.contains('.') ? name.substring(0, name.lastIndexOf('.')) : name;
    return RegExp(r'^(img|dsc|pxl|dscf|p\d|photo|image)[_\-]?\d', caseSensitive: false).hasMatch(stem) ? '' : stem;
  }
}

class UploadScreen extends ConsumerStatefulWidget {
  const UploadScreen({super.key});

  @override
  ConsumerState<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends ConsumerState<UploadScreen> {
  final List<_Pending> _items = [];
  int _selected = 0;
  String? _roomId;
  final _year = TextEditingController(text: DateTime.now().year.toString());
  String _medium = '';
  bool _watermark = false;
  bool _ratings = true;
  bool _dragging = false;
  int? _done;

  @override
  void dispose() {
    for (final p in _items) {
      p.dispose();
    }
    _year.dispose();
    super.dispose();
  }

  Future<void> _add(List<XFile> files) async {
    final l10n = context.l10n;
    var skipped = false;
    final added = <_Pending>[];
    for (final f in files) {
      if (await f.length() > maxUploadBytes) {
        skipped = true;
        continue;
      }
      added.add(_Pending(f.name, await f.readAsBytes()));
    }
    if (!mounted) return;
    if (skipped) context.toast(l10n.fileTooLarge);
    setState(() {
      _items.addAll(added);
      if (added.isNotEmpty) _selected = _items.length - added.length;
    });
  }

  Future<void> _pick() async => _add(await ref.read(pickImagesProvider)());

  void _remove(int i) => setState(() {
    _items.removeAt(i).dispose();
    _selected = _selected.clamp(0, (_items.length - 1).clamp(0, 1 << 30));
  });

  Future<void> _submit(Gallery gallery, List<Room> rooms) async {
    final l10n = context.l10n;
    final roomId = _roomId ?? rooms.firstOrNull?.id;
    if (roomId == null) return context.toast(l10n.needRoom);
    final missing = _items.indexWhere((p) => p.title.text.trim().isEmpty);
    if (missing >= 0) {
      setState(() => _selected = missing);
      return context.toast(l10n.titleRequired);
    }

    final repo = ref.read(repositoryProvider);
    setState(() => _done = 0);
    while (_items.isNotEmpty) {
      final p = _items.first;
      try {
        await repo.uploadArtwork(
          gallery: gallery,
          imageBytes: p.bytes,
          draft: ArtworkDraft(
            roomId: roomId,
            title: p.title.text,
            titleEn: p.titleEn.text,
            year: int.tryParse(_year.text.trim()),
            medium: _medium,
            sizeText: p.size.text,
            note: p.note.text,
            noteEn: p.noteEn.text,
            watermark: _watermark,
            ratingEnabled: _ratings,
          ),
        );
      } catch (e) {
        if (mounted) {
          context.toast(errorText(l10n, e));
          setState(() {
            _done = null;
            _selected = 0;
          });
        }
        _refresh(gallery, roomId);
        return;
      }
      if (!mounted) return;
      setState(() {
        _items.removeAt(0).dispose();
        _done = _done! + 1;
      });
    }
    _refresh(gallery, roomId);
    if (mounted) {
      context.toast(l10n.uploadDone);
      setState(() {
        _done = null;
        _selected = 0;
      });
    }
  }

  void _refresh(Gallery gallery, String roomId) {
    ref.invalidate(artworksProvider(roomId));
    ref.invalidate(roomsProvider(gallery.id));
    ref.invalidate(artworkCountProvider(gallery.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final gallery = ref.watch(myGalleryProvider).value;
    if (gallery == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final rooms = ref.watch(roomsProvider(gallery.id)).value ?? const <Room>[];
    final uploading = _done != null;
    final total = (_done ?? 0) + _items.length;

    Widget body = ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        _dropZone(l10n),
        if (_items.isNotEmpty) ...[const SizedBox(height: 12), _thumbnails(l10n)],
        const SizedBox(height: 8),
        if (uploading) ...[
          Text(l10n.uploading(_done!, total), style: const TextStyle(fontSize: 12, color: Palette.muted)),
          const SizedBox(height: 6),
          LinearProgressIndicator(value: total == 0 ? null : _done! / total, backgroundColor: Palette.line),
        ] else
          Text(l10n.gpsRemoved, style: const TextStyle(fontSize: 12, color: Palette.muted)),
        if (_items.isNotEmpty) ...[
          const SizedBox(height: 16),
          _perImageFields(l10n, _items[_selected]),
          const SizedBox(height: 12),
          _sharedFields(l10n, rooms),
        ],
      ],
    );

    if (ref.watch(enableDropTargetProvider)) {
      body = DropTarget(
        onDragEntered: (_) => setState(() => _dragging = true),
        onDragExited: (_) => setState(() => _dragging = false),
        onDragDone: (d) {
          setState(() => _dragging = false);
          _add(d.files);
        },
        child: body,
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.uploadTitle)),
      body: Center(
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 720), child: body),
      ),
      bottomNavigationBar: _items.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: FilledButton(
                  onPressed: uploading ? null : () => _submit(gallery, rooms),
                  child: Text(l10n.hangArtwork),
                ),
              ),
            ),
    );
  }

  Widget _dropZone(AppLocalizations l10n) {
    final desktop = ref.watch(enableDropTargetProvider);
    return InkWell(
      onTap: _done == null ? _pick : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: _items.isEmpty ? 180 : 88,
        decoration: BoxDecoration(
          color: _dragging ? Palette.accentSoft : const Color(0xFFFBFAF7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _dragging ? Palette.accent : const Color(0xFFB9B4A8), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_photo_alternate_outlined, color: Palette.muted),
            const SizedBox(height: 6),
            Text(
              desktop ? '${l10n.dropHere} · ${l10n.pickPhotos}' : l10n.pickPhotos,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            Text(l10n.dropFormats, style: const TextStyle(fontSize: 12, color: Palette.muted)),
          ],
        ),
      ),
    );
  }

  Widget _thumbnails(AppLocalizations l10n) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => Stack(
          children: [
            GestureDetector(
              onTap: () => setState(() => _selected = i),
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: i == _selected ? Palette.accent : Colors.transparent, width: 2),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(_items[i].bytes, fit: BoxFit.cover, cacheWidth: 200, semanticLabel: _items[i].name),
              ),
            ),
            if (_done == null)
              // Kept to the corner so tapping the photo selects it rather than removing it.
              Positioned(
                right: 2,
                top: 2,
                child: Tooltip(
                  message: l10n.delete,
                  child: Semantics(
                    button: true,
                    label: '${l10n.delete} ${_items[i].name}',
                    child: InkWell(
                      onTap: () => _remove(i),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(color: Color(0xCC1D1C1A), shape: BoxShape.circle),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _perImageFields(AppLocalizations l10n, _Pending p) {
    return Column(
      key: ObjectKey(p),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: p.title,
          maxLength: 80,
          decoration: InputDecoration(labelText: l10n.title),
        ),
        TextField(
          controller: p.titleEn,
          maxLength: 80,
          decoration: InputDecoration(labelText: l10n.titleEn),
        ),
        TextField(
          controller: p.size,
          decoration: InputDecoration(labelText: l10n.size, hintText: '32×24cm'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: p.note,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(labelText: l10n.artistNote),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: p.noteEn,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(labelText: l10n.artistNoteEn),
        ),
      ],
    );
  }

  Widget _sharedFields(AppLocalizations l10n, List<Room> rooms) {
    final media = {
      l10n.mediumWatercolor: l10n.mediumWatercolor,
      l10n.mediumOil: l10n.mediumOil,
      l10n.mediumAcrylic: l10n.mediumAcrylic,
      l10n.mediumPhoto: l10n.mediumPhoto,
      l10n.mediumDigital: l10n.mediumDigital,
      l10n.mediumOther: l10n.mediumOther,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _year,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.year),
        ),
        const SizedBox(height: 16),
        Text(l10n.medium, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final m in media.keys)
              ChoiceChip(
                label: Text(m),
                selected: _medium == m,
                onSelected: (s) => setState(() => _medium = s ? m : ''),
              ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _roomId ?? rooms.firstOrNull?.id,
          decoration: InputDecoration(labelText: l10n.room),
          items: [for (final r in rooms) DropdownMenuItem(value: r.id, child: Text(r.title))],
          onChanged: (v) => setState(() => _roomId = v),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.watermark),
          value: _watermark,
          onChanged: (v) => setState(() => _watermark = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.acceptRatings),
          value: _ratings,
          onChanged: (v) => setState(() => _ratings = v),
        ),
      ],
    );
  }
}
