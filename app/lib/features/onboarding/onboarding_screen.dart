import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../ui/common.dart';

/// Three short steps from a new account to an open gallery: field, name and address, theme.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;
  ArtField _field = ArtField.painting;
  GalleryTheme _theme = GalleryTheme.white;
  final _title = TextEditingController();
  final _handle = TextEditingController();
  bool? _handleAvailable;
  Timer? _debounce;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _title.dispose();
    _handle.dispose();
    super.dispose();
  }

  void _onHandleChanged(String raw) {
    final handle = normalizeHandle(raw);
    _debounce?.cancel();
    setState(() => _handleAvailable = null);
    if (!isValidHandle(handle)) return;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final ok = await ref.read(repositoryProvider).isHandleAvailable(handle);
      if (mounted && normalizeHandle(_handle.text) == handle) setState(() => _handleAvailable = ok);
    });
  }

  bool get _step2Valid =>
      _title.text.trim().isNotEmpty && isValidHandle(normalizeHandle(_handle.text)) && _handleAvailable != false;

  Future<void> _finish() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(repositoryProvider)
          .createGallery(
            handle: normalizeHandle(_handle.text),
            title: _title.text.trim(),
            field: _field,
            theme: _theme,
            firstRoomTitle: l10n.firstRoomName,
          );
      ref.invalidate(myGalleryProvider);
    } catch (e) {
      setState(() {
        _error = errorText(l10n, e);
        _step = 1;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final steps = [_fieldStep(), _nameStep(), _themeStep()];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.onboardingTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: (_step + 1) / steps.length, backgroundColor: Palette.line),
                  const SizedBox(height: 24),
                  Expanded(child: SingleChildScrollView(child: steps[_step])),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ),
                  Row(
                    children: [
                      if (_step > 0) OutlinedButton(onPressed: () => setState(() => _step--), child: Text(l10n.back)),
                      const Spacer(),
                      FilledButton(
                        onPressed: _busy || (_step == 1 && !_step2Valid)
                            ? null
                            : () => _step < steps.length - 1 ? setState(() => _step++) : _finish(),
                        child: Text(_step < steps.length - 1 ? l10n.next : l10n.openGallery),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldStep() {
    final l10n = context.l10n;
    final options = {
      ArtField.painting: l10n.fieldPainting,
      ArtField.photo: l10n.fieldPhoto,
      ArtField.illustration: l10n.fieldIllustration,
      ArtField.other: l10n.fieldOther,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.stepField, style: serifTitle.copyWith(fontSize: 22)),
        const SizedBox(height: 16),
        RadioGroup<ArtField>(
          groupValue: _field,
          onChanged: (v) => setState(() => _field = v!),
          child: Column(
            children: [for (final e in options.entries) RadioListTile<ArtField>(value: e.key, title: Text(e.value))],
          ),
        ),
      ],
    );
  }

  Widget _nameStep() {
    final l10n = context.l10n;
    final handle = normalizeHandle(_handle.text);
    String? helper;
    if (handle.isNotEmpty && !isValidHandle(handle)) {
      helper = l10n.handleRule;
    } else if (_handleAvailable == false) {
      helper = l10n.handleTaken;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _title,
          decoration: InputDecoration(labelText: l10n.galleryTitle),
          maxLength: 60,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _handle,
          decoration: InputDecoration(
            labelText: l10n.galleryAddress,
            prefixText: '$siteHost/@',
            helperText: l10n.handleRule,
            errorText: helper,
            suffixIcon: _handleAvailable == true ? const Icon(Icons.check, color: Palette.accent) : null,
          ),
          autocorrect: false,
          onChanged: _onHandleChanged,
        ),
      ],
    );
  }

  Widget _themeStep() {
    final l10n = context.l10n;
    final names = {
      GalleryTheme.white: l10n.themeWhite,
      GalleryTheme.dark: l10n.themeDark,
      GalleryTheme.wood: l10n.themeWood,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.theme, style: serifTitle.copyWith(fontSize: 22)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final t in GalleryTheme.values)
              _ThemeSwatch(
                name: names[t]!,
                colors: galleryColors(t),
                selected: _theme == t,
                onTap: () => setState(() => _theme = t),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.startsUnlisted, style: const TextStyle(color: Palette.muted, height: 1.5)),
      ],
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.name, required this.colors, required this.selected, required this.onTap});

  final String name;
  final ({Color ground, Color ink, Color muted, Color frame}) colors;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 128,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.ground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? Palette.accent : Palette.line, width: selected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 64,
                decoration: BoxDecoration(
                  border: Border.all(color: colors.frame, width: 4),
                  color: const Color(0xFFDFE7EE),
                ),
              ),
              const SizedBox(height: 8),
              ExcludeSemantics(
                child: Text(name, style: TextStyle(color: colors.ink, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
