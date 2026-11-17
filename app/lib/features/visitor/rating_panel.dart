import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../ui/common.dart';

/// Four 1–5 scores (composition, color, technique, feeling), plus the public
/// averages once there are enough ratings to show them fairly.
class RatingPanel extends ConsumerStatefulWidget {
  const RatingPanel({super.key, required this.gallery, required this.artwork});

  final Gallery gallery;
  final Artwork artwork;

  @override
  ConsumerState<RatingPanel> createState() => _RatingPanelState();
}

class _RatingPanelState extends ConsumerState<RatingPanel> {
  List<int>? _scores;
  bool _busy = false;
  bool _sent = false;

  bool get _complete => _scores != null && _scores!.every((s) => s > 0);

  Future<void> _send() async {
    final l10n = context.l10n;
    final s = _scores!;
    setState(() => _busy = true);
    try {
      await ref.read(repositoryProvider).rate(
            widget.artwork.id,
            Rating(composition: s[0], color: s[1], technique: s[2], emotion: s[3]),
          );
      ref.invalidate(ratingStatsProvider(widget.artwork.id));
      ref.invalidate(myRatingProvider(widget.artwork.id));
      setState(() => _sent = true);
    } catch (e) {
      if (mounted) context.toast(errorText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uid = ref.watch(userIdProvider).value;
    final stats = ref.watch(ratingStatsProvider(widget.artwork.id)).value;
    final criteria = [l10n.composition, l10n.color, l10n.technique, l10n.emotion];
    final isOwner = uid != null && uid == widget.gallery.ownerId;
    final open = widget.gallery.ratingEnabled && widget.artwork.ratingEnabled;

    Widget note(String text) =>
        Text(text, style: const TextStyle(fontSize: 12, height: 1.5, color: Palette.darkMuted));

    final children = <Widget>[
      Text(l10n.rateThis, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Palette.darkInk)),
      const SizedBox(height: 6),
    ];

    if (stats != null && (stats.count >= RatingStats.publicThreshold || isOwner)) {
      children.addAll([
        note(l10n.ratingAverages(stats.count)),
        const SizedBox(height: 8),
        _Averages(labels: criteria, values: [stats.composition, stats.color, stats.technique, stats.emotion]),
        const SizedBox(height: 12),
      ]);
    }

    if (!open) {
      children.add(note(l10n.ratingsOff));
    } else if (isOwner) {
      children.add(note(l10n.ownArtwork));
    } else if (uid == null) {
      children.addAll([
        note(l10n.signInToReact),
        const SizedBox(height: 8),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: Palette.darkInk, side: const BorderSide(color: Color(0xFF4A4843))),
          onPressed: () => context.push('/welcome'),
          child: Text(l10n.signIn),
        ),
      ]);
    } else if (_sent) {
      children.add(Semantics(
        liveRegion: true,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: const Color(0xFF2A2926), borderRadius: BorderRadius.circular(10)),
          child: Text(l10n.ratingSent, style: const TextStyle(color: Palette.darkInk)),
        ),
      ));
    } else {
      final mine = ref.watch(myRatingProvider(widget.artwork.id));
      if (mine.isLoading) return const SizedBox(height: 120);
      final existing = mine.value;
      _scores ??= existing == null
          ? [0, 0, 0, 0]
          : [existing.composition, existing.color, existing.technique, existing.emotion];
      for (var i = 0; i < criteria.length; i++) {
        children.add(_StarRow(
          label: criteria[i],
          value: _scores![i],
          onChanged: (v) => setState(() => _scores![i] = v),
        ));
      }
      children.addAll([
        const SizedBox(height: 4),
        note(l10n.ratingNote),
        const SizedBox(height: 12),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Palette.darkAccent,
            foregroundColor: Palette.darkGround,
            disabledBackgroundColor: const Color(0xFF2A2926),
            disabledForegroundColor: const Color(0xFF8A8780),
          ),
          onPressed: _complete && !_busy ? _send : null,
          child: Text(existing == null ? l10n.submitRating : l10n.updateRating),
        ),
      ]);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: const BoxDecoration(
        color: Palette.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      height: 44,
      child: Row(children: [
        SizedBox(width: 72, child: Text(label, style: const TextStyle(color: Color(0xFFD6D3CC)))),
        for (var n = 1; n <= 5; n++)
          IconButton(
            tooltip: l10n.starLabel(label, n),
            isSelected: n <= value,
            onPressed: () => onChanged(n),
            icon: const Icon(Icons.star_border, color: Color(0xFF6E6B66)),
            selectedIcon: const Icon(Icons.star, color: Palette.darkAccent),
          ),
        const Spacer(),
        Text(value == 0 ? '—' : '$value / 5', style: const TextStyle(fontSize: 13, color: Palette.darkMuted)),
      ]),
    );
  }
}

class _Averages extends StatelessWidget {
  const _Averages({required this.labels, required this.values});

  final List<String> labels;
  final List<double> values;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < labels.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            SizedBox(width: 72, child: Text(labels[i], style: const TextStyle(fontSize: 13, color: Color(0xFFD6D3CC)))),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: values[i] / 5,
                  minHeight: 6,
                  color: Palette.darkAccent,
                  backgroundColor: const Color(0xFF2E2D2A),
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: Text(values[i].toStringAsFixed(1),
                  textAlign: TextAlign.end, style: const TextStyle(fontSize: 13, color: Palette.darkMuted)),
            ),
          ]),
        ),
    ]);
  }
}
