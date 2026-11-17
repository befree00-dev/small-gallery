import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../ui/common.dart';

/// Gallery details and policies, language, plan usage, sign-out.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late Gallery _g;
  late final _title = TextEditingController();
  late final _titleEn = TextEditingController();
  late final _bio = TextEditingController();
  late final _bioEn = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _g = ref.read(myGalleryProvider).value!;
    _title.text = _g.title;
    _titleEn.text = _g.titleEn ?? '';
    _bio.text = _g.bio;
    _bioEn.text = _g.bioEn ?? '';
  }

  @override
  void dispose() {
    for (final c in [_title, _titleEn, _bio, _bioEn]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (_title.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(repositoryProvider)
          .updateGallery(
            _g.copyWith(
              title: _title.text.trim(),
              titleEn: _titleEn.text.trim(),
              bio: _bio.text.trim(),
              bioEn: _bioEn.text.trim(),
            ),
          );
      ref.invalidate(myGalleryProvider);
      if (mounted) context.toast(l10n.saved);
    } catch (e) {
      if (mounted) context.toast(errorText(l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = ref.watch(localeProvider);
    final profile = ref.watch(myProfileProvider).value;
    final count = ref.watch(artworkCountProvider(_g.id)).value;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        actions: [
          FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.save)),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Text(l10n.galleryInfo, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                maxLength: 60,
                decoration: InputDecoration(labelText: l10n.galleryTitle),
              ),
              TextField(
                controller: _titleEn,
                maxLength: 60,
                decoration: InputDecoration(labelText: l10n.titleEn),
              ),
              TextField(
                controller: _bio,
                minLines: 2,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(labelText: l10n.bio),
              ),
              TextField(
                controller: _bioEn,
                minLines: 1,
                maxLines: 5,
                maxLength: 500,
                decoration: InputDecoration(labelText: l10n.bioEn),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<GalleryTheme>(
                initialValue: _g.theme,
                decoration: InputDecoration(labelText: l10n.theme),
                items: [
                  DropdownMenuItem(value: GalleryTheme.white, child: Text(l10n.themeWhite)),
                  DropdownMenuItem(value: GalleryTheme.dark, child: Text(l10n.themeDark)),
                  DropdownMenuItem(value: GalleryTheme.wood, child: Text(l10n.themeWood)),
                ],
                onChanged: (v) => setState(() => _g = _g.copyWith(theme: v)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<Audience>(
                initialValue: _g.visibility,
                decoration: InputDecoration(labelText: l10n.visibility),
                items: [
                  for (final v in Audience.values) DropdownMenuItem(value: v, child: Text(visibilityLabel(l10n, v))),
                ],
                onChanged: (v) => setState(() => _g = _g.copyWith(visibility: v)),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<CommentPolicy>(
                initialValue: _g.commentPolicy,
                decoration: InputDecoration(labelText: l10n.commentPolicy),
                items: [
                  DropdownMenuItem(value: CommentPolicy.approve, child: Text(l10n.policyApprove)),
                  DropdownMenuItem(value: CommentPolicy.open, child: Text(l10n.policyOpen)),
                  DropdownMenuItem(value: CommentPolicy.off, child: Text(l10n.policyOff)),
                ],
                onChanged: (v) => setState(() => _g = _g.copyWith(commentPolicy: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.ratingsOnGallery),
                value: _g.ratingEnabled,
                onChanged: (v) => setState(() => _g = _g.copyWith(ratingEnabled: v)),
              ),
              const Divider(height: 32),
              Text(l10n.language, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'ko', label: Text('한국어')),
                  ButtonSegment(value: 'en', label: Text('English')),
                ],
                selected: {locale.languageCode},
                onSelectionChanged: (s) => ref.read(localeProvider.notifier).set(Locale(s.first)),
              ),
              const Divider(height: 32),
              if (profile != null && count != null) ...[
                Text(
                  l10n.planUsage(profile.plan == 'plus' ? 'Plus' : 'Free', count, profile.artworkLimit),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: count / profile.artworkLimit, backgroundColor: Palette.line),
                const SizedBox(height: 24),
              ],
              OutlinedButton(
                onPressed: () async {
                  await ref.read(repositoryProvider).signOut();
                  ref.invalidate(myGalleryProvider);
                },
                child: Text(l10n.signOut),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
