import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../theme.dart';
import '../../ui/common.dart';

// Layouts for the themes that change more than color, matching the web
// gallery (web/components/gallery-layouts.tsx). Each returns slivers.

/// Works grouped by room, rooms and works in hanging order; empty rooms dropped.
typedef RoomGroup = ({Room room, List<Artwork> works});

List<RoomGroup> groupWorks(List<Room> rooms, List<Artwork> works, Map<String, Room> roomOf) {
  final sorted = [...rooms]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return [for (final r in sorted) (room: r, works: works.where((w) => roomOf[w.id]?.id == r.id).toList())]
      .where((g) => g.works.isNotEmpty)
      .toList();
}

String _compact(BuildContext context, int n) {
  if (n < 1000) return '$n';
  if (n < 10000) return '${(n / 1000).toStringAsFixed(1)}K'.replaceAll('.0K', 'K');
  return context.lang == 'ko' ? '${(n / 10000).toStringAsFixed(1)}만'.replaceAll('.0만', '만') : '${(n / 1000).round()}K';
}

// ---------------------------------------------------------------------------
// 피드: social-profile style
// ---------------------------------------------------------------------------

class FeedColors {
  static const ground = Color(0xFFFFFFFF);
  static const ink = Color(0xFF121212);
  static const inkSoft = Color(0xFF262626);
  static const muted = Color(0xFF6E6E6E);
  static const line = Color(0xFFE4E4E4);
  static const lineStrong = Color(0xFFCFCFCF);
  static const accent = Color(0xFF2E4AA6);
}

class FeedLayout extends StatefulWidget {
  const FeedLayout({super.key, required this.gallery, required this.groups, required this.onTap});

  final Gallery gallery;
  final List<RoomGroup> groups;
  final ValueChanged<Artwork> onTap;

  @override
  State<FeedLayout> createState() => _FeedLayoutState();
}

class _FeedLayoutState extends State<FeedLayout> {
  String? _roomId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = context.lang;
    final g = widget.gallery;
    final all = [for (final grp in widget.groups) ...grp.works];
    final shown = _roomId == null ? all : widget.groups.firstWhere((x) => x.room.id == _roomId).works;
    final cover = all.where((a) => a.isFeatured).firstOrNull ?? all.firstOrNull;
    final likes = all.fold(0, (s, a) => s + a.likeCount);
    final bio = localized(g.bio, g.bioEn, lang);
    final avatar = (MediaQuery.sizeOf(context).width * 0.22).clamp(86.0, 150.0);

    Widget stat(int n, String label) => Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: _compact(context, n),
            style: const TextStyle(fontWeight: FontWeight.w600, color: FeedColors.ink),
          ),
          TextSpan(text: ' $label'),
        ],
      ),
      style: const TextStyle(fontSize: 15, color: FeedColors.inkSoft),
    );

    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 935),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: avatar,
                      height: avatar,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: FeedColors.accent),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: FeedColors.ground),
                        child: ClipOval(
                          child: cover == null
                              ? const ColoredBox(color: FeedColors.line)
                              : ArtworkImage(path: cover.thumbPath, semanticLabel: ''),
                        ),
                      ),
                    ),
                    SizedBox(width: math.min(64, MediaQuery.sizeOf(context).width * 0.06)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.handle, style: const TextStyle(fontSize: 21, color: FeedColors.ink)),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 22,
                            runSpacing: 4,
                            children: [
                              stat(all.length, l10n.statWorks),
                              stat(widget.groups.length, l10n.statRooms),
                              stat(likes, l10n.statLikes),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            localized(g.title, g.titleEn, lang),
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: FeedColors.ink),
                          ),
                          if (g.ownerName.isNotEmpty)
                            Text(g.ownerName, style: const TextStyle(fontSize: 14, color: FeedColors.muted)),
                          if (bio.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(bio, style: const TextStyle(fontSize: 14, height: 1.5, color: FeedColors.ink)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.groups.length > 1)
                SizedBox(
                  height: 112,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _Highlight(
                        label: l10n.all,
                        selected: _roomId == null,
                        onTap: () => setState(() => _roomId = null),
                        child: Center(
                          child: Text(
                            '${all.length}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: FeedColors.inkSoft,
                            ),
                          ),
                        ),
                      ),
                      for (final grp in widget.groups)
                        _Highlight(
                          label: localized(grp.room.title, grp.room.titleEn, lang),
                          selected: _roomId == grp.room.id,
                          onTap: () => setState(() => _roomId = grp.room.id),
                          child: ArtworkImage(path: grp.works.first.thumbPath, semanticLabel: ''),
                        ),
                    ],
                  ),
                ),
              Container(
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: FeedColors.line)),
                ),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: FeedColors.ink)),
                  ),
                  child: Text(
                    l10n.statWorks.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: FeedColors.ink,
                    ),
                  ),
                ),
              ),
              GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final a in shown)
                    Semantics(
                      button: true,
                      label: '${localized(a.title, a.titleEn, lang)}, ${l10n.like} ${a.likeCount}',
                      child: InkWell(
                        onTap: () => widget.onTap(a),
                        child: ExcludeSemantics(
                          child: ArtworkImage(path: a.thumbPath, semanticLabel: ''),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Highlight extends StatelessWidget {
  const _Highlight({required this.label, required this.selected, required this.onTap, required this.child});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 84,
          child: Column(
            children: [
              const SizedBox(height: 4),
              Container(
                width: 70,
                height: 70,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? FeedColors.accent : FeedColors.lineStrong,
                    width: selected ? 2 : 1.5,
                  ),
                ),
                child: ClipOval(
                  child: ExcludeSemantics(
                    child: ColoredBox(color: const Color(0xFFFAFAFA), child: child),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ExcludeSemantics(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: FeedColors.ink,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 살롱: classic museum wall
// ---------------------------------------------------------------------------

class SalonColors {
  static const wall = Color(0xFF1D2A24);
  static const ink = Color(0xFFF1EBDD);
  static const inkSoft = Color(0xFFDDD4C2);
  static const muted = Color(0xFFB9AE99);
  static const gold = Color(0xFFC9A45C);
  static const mat = Color(0xFFF3EEE2);
  static const labelInk = Color(0xFF2A2620);
  static const labelMuted = Color(0xFF5D564B);
}

class SalonLayout extends StatelessWidget {
  const SalonLayout({super.key, required this.gallery, required this.groups, required this.onTap});

  final Gallery gallery;
  final List<RoomGroup> groups;
  final ValueChanged<Artwork> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lang = context.lang;
    final g = gallery;
    final bio = localized(g.bio, g.bioEn, lang);
    final size = MediaQuery.sizeOf(context);
    final twoUp = size.width >= 900;

    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
            child: Column(
              children: [
                Text(l10n.exhibition, style: const TextStyle(fontSize: 12, letterSpacing: 6, color: SalonColors.gold)),
                const SizedBox(height: 14),
                Text(
                  localized(g.title, g.titleEn, lang),
                  textAlign: TextAlign.center,
                  style: serif(
                    TextStyle(
                      fontSize: (size.width * 0.06).clamp(34, 58).toDouble(),
                      height: 1.2,
                      color: SalonColors.ink,
                    ),
                  ),
                ),
                if (g.ownerName.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(g.ownerName, style: serif(const TextStyle(fontSize: 18, color: SalonColors.inkSoft))),
                ],
                Container(
                  width: 72,
                  height: 1,
                  color: SalonColors.gold,
                  margin: const EdgeInsets.symmetric(vertical: 26),
                ),
                if (bio.isNotEmpty)
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: Text(
                      bio,
                      textAlign: TextAlign.center,
                      style: const TextStyle(height: 1.8, color: SalonColors.inkSoft),
                    ),
                  ),
                for (final grp in groups) ...[
                  const SizedBox(height: 48),
                  Text(
                    localized(grp.room.title, grp.room.titleEn, lang),
                    textAlign: TextAlign.center,
                    style: serif(const TextStyle(fontSize: 26, letterSpacing: 1, color: SalonColors.ink)),
                  ),
                  if (localized(grp.room.statement, grp.room.statementEn, lang).isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Text(
                          localized(grp.room.statement, grp.room.statementEn, lang),
                          textAlign: TextAlign.center,
                          style: const TextStyle(height: 1.8, color: SalonColors.muted),
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                  // Pieces hang along a shared bottom line, two to a row on wide screens.
                  for (var i = 0; i < grp.works.length; i += twoUp ? 2 : 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 56),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var j = i; j < math.min(i + (twoUp ? 2 : 1), grp.works.length); j++) ...[
                            if (j > i) const SizedBox(width: 48),
                            Expanded(
                              child: _SalonPiece(
                                artwork: grp.works[j],
                                artist: g.ownerName,
                                maxImageHeight: size.height * 0.56,
                                onTap: () => onTap(grp.works[j]),
                              ),
                            ),
                          ],
                          if (twoUp && i + 1 >= grp.works.length) ...[const SizedBox(width: 48), const Spacer()],
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SalonPiece extends StatelessWidget {
  const _SalonPiece({required this.artwork, required this.artist, required this.maxImageHeight, required this.onTap});

  final Artwork artwork;
  final String artist;
  final double maxImageHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = artwork;
    final title = localized(a.title, a.titleEn, context.lang);
    final mat = (MediaQuery.sizeOf(context).width * 0.03).clamp(16.0, 30.0);
    return Semantics(
      button: true,
      label: title,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            LayoutBuilder(
              builder: (context, box) {
                // Fit the work inside the column width and the height limit, keeping proportions.
                final inner = box.maxWidth - 2 * (14 + mat);
                final w = math.min(inner, maxImageHeight * a.aspectRatio);
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF4A3423), Color(0xFF2B1C12), Color(0xFF3D2A1C)],
                    ),
                    boxShadow: const [
                      BoxShadow(color: Color(0xBF000000), blurRadius: 40, offset: Offset(0, 22), spreadRadius: -18),
                      BoxShadow(color: Color(0x80000000), blurRadius: 14, offset: Offset(0, 8), spreadRadius: -6),
                    ],
                  ),
                  child: Container(
                    padding: EdgeInsets.all(mat),
                    color: SalonColors.mat,
                    child: SizedBox(
                      width: w,
                      child: AspectRatio(
                        aspectRatio: a.aspectRatio,
                        child: ExcludeSemantics(
                          child: ArtworkImage(path: a.imagePath, semanticLabel: ''),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
            Container(
              constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              color: SalonColors.mat,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: serif(
                      const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: SalonColors.labelInk),
                    ),
                  ),
                  Text(
                    [if (artist.isNotEmpty) artist, if (a.year != null) '${a.year}'].join(', '),
                    style: const TextStyle(fontSize: 12, color: SalonColors.labelMuted),
                  ),
                  if (a.medium.isNotEmpty || a.sizeText.isNotEmpty)
                    Text(
                      [if (a.medium.isNotEmpty) a.medium, if (a.sizeText.isNotEmpty) a.sizeText].join(' · '),
                      style: const TextStyle(fontSize: 12, color: SalonColors.labelMuted),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 에디토리얼: art-magazine spread
// ---------------------------------------------------------------------------

class EditorialColors {
  static const paper = Color(0xFFF3EFE6);
  static const ink = Color(0xFF161514);
  static const inkSoft = Color(0xFF2E2C29);
  static const muted = Color(0xFF6A655C);
  static const accent = Color(0xFFB23A12);
  static const line = Color(0xFFD9D2C4);
}

class EditorialLayout extends StatelessWidget {
  const EditorialLayout({super.key, required this.gallery, required this.groups, required this.onTap});

  final Gallery gallery;
  final List<RoomGroup> groups;
  final ValueChanged<Artwork> onTap;

  /// Column spans on a 12-column grid; the rhythm runs across the whole gallery.
  static const spans = [12, 7, 5, 5, 7, 4, 4, 4];

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final g = gallery;
    final bio = localized(g.bio, g.bioEn, lang);
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 720;
    var n = 0;

    final chapters = <Widget>[];
    for (var ri = 0; ri < groups.length; ri++) {
      final grp = groups[ri];
      // Pack the pieces into rows whose spans add up to 12.
      final rows = <List<(Artwork, int, int)>>[];
      var row = <(Artwork, int, int)>[];
      var used = 0;
      for (final a in grp.works) {
        final span = narrow ? 12 : spans[n % spans.length];
        n += 1;
        if (used + span > 12) {
          rows.add(row);
          row = [];
          used = 0;
        }
        row.add((a, span, n));
        used += span;
      }
      if (row.isNotEmpty) rows.add(row);

      chapters.addAll([
        const SizedBox(height: 56),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              (ri + 1).toString().padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                color: EditorialColors.accent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                localized(grp.room.title, grp.room.titleEn, lang),
                style: serif(
                  TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: (size.width * 0.04).clamp(26, 40).toDouble(),
                    color: EditorialColors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (localized(grp.room.statement, grp.room.statementEn, lang).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Text(
                localized(grp.room.statement, grp.room.statementEn, lang),
                style: serif(const TextStyle(height: 1.8, color: EditorialColors.inkSoft)),
              ),
            ),
          ),
        const SizedBox(height: 36),
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 44),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var k = 0; k < r.length; k++) ...[
                  if (k > 0) const SizedBox(width: 24),
                  Expanded(
                    flex: r[k].$2,
                    child: Padding(
                      // A narrow piece beside a wide one drops a little, as in the web layout.
                      padding: EdgeInsets.only(top: r[k].$2 == 5 && r.length > 1 ? 48 : 0),
                      child: _EditorialPiece(
                        artwork: r[k].$1,
                        number: r[k].$3,
                        full: r[k].$2 == 12,
                        maxHeight: size.height * 0.78,
                        onTap: () => onTap(r[k].$1),
                      ),
                    ),
                  ),
                ],
                // Leave the rest of a short row empty, like the web grid.
                if (r.fold(0, (s, x) => s + x.$2) < 12) Spacer(flex: 12 - r.fold(0, (s, x) => s + x.$2)),
              ],
            ),
          ),
      ]);
    }

    return SliverToBoxAdapter(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 32, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  localized(g.title, g.titleEn, lang),
                  style: serif(
                    TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: (size.width * 0.1).clamp(44, 128).toDouble(),
                      height: 1.0,
                      letterSpacing: -1.5,
                      color: EditorialColors.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: EdgeInsets.only(left: narrow ? 0 : size.width * 0.35),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (g.ownerName.isNotEmpty)
                        Text(
                          g.ownerName.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: EditorialColors.ink,
                          ),
                        ),
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(bio, style: serif(const TextStyle(fontSize: 17, height: 1.7, color: EditorialColors.ink))),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Container(height: 2, color: EditorialColors.ink),
                ...chapters,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditorialPiece extends StatelessWidget {
  const _EditorialPiece({
    required this.artwork,
    required this.number,
    required this.full,
    required this.maxHeight,
    required this.onTap,
  });

  final Artwork artwork;
  final int number;
  final bool full;
  final double maxHeight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = artwork;
    final title = localized(a.title, a.titleEn, context.lang);
    return Semantics(
      button: true,
      label: '${number.toString().padLeft(2, '0')} $title',
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, box) {
                // Full-width pieces stay within one screen; tall works are centred, not cropped.
                final w = full ? math.min(box.maxWidth, maxHeight * a.aspectRatio) : box.maxWidth;
                return Center(
                  child: SizedBox(
                    width: w,
                    child: AspectRatio(
                      aspectRatio: a.aspectRatio,
                      child: ExcludeSemantics(
                        child: ArtworkImage(path: full ? a.imagePath : a.thumbPath, semanticLabel: ''),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Container(height: 1, color: EditorialColors.ink),
            const SizedBox(height: 12),
            ExcludeSemantics(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    number.toString().padLeft(2, '0'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: EditorialColors.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: serif(const TextStyle(fontSize: 17, color: EditorialColors.ink))),
                  ),
                  if (a.year != null)
                    Text('${a.year}', style: const TextStyle(fontSize: 12, color: EditorialColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
