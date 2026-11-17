import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../state/providers.dart';
import '../../theme.dart';
import '../../ui/common.dart';

/// Sign in or create an account; or visit someone's gallery without one.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _handle = TextEditingController();
  bool _signingUp = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    for (final c in [_email, _password, _name, _handle]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l10n = context.l10n;
    final repo = ref.read(repositoryProvider);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_signingUp) {
        final ready = await repo.signUp(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim(),
          locale: ref.read(localeProvider).languageCode,
        );
        if (!ready) setState(() => _message = l10n.checkEmail);
      } else {
        await repo.signIn(email: _email.text.trim(), password: _password.text);
      }
    } catch (_) {
      setState(() => _message = l10n.authFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _visit() {
    final handle = normalizeHandle(_handle.text);
    if (isValidHandle(handle)) context.push('/g/$handle');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _LanguageSwitch(),
                    const SizedBox(height: 24),
                    Text(
                      'Small Gallery',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Palette.muted),
                    ),
                    const SizedBox(height: 8),
                    Text(l10n.welcomeHeadline, style: serifTitle.copyWith(fontSize: 26, height: 1.3)),
                    const SizedBox(height: 8),
                    Text(l10n.welcomeBody, style: const TextStyle(color: Palette.muted, height: 1.6)),
                    const SizedBox(height: 32),
                    if (_signingUp) ...[
                      TextFormField(
                        controller: _name,
                        decoration: InputDecoration(labelText: l10n.displayName),
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v ?? '').trim().isEmpty ? l10n.displayName : null,
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _email,
                      decoration: InputDecoration(labelText: l10n.email),
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v ?? '').contains('@') ? null : l10n.email,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _password,
                      decoration: InputDecoration(
                        labelText: l10n.password,
                        helperText: _signingUp ? l10n.passwordRule : null,
                      ),
                      obscureText: true,
                      autofillHints: [_signingUp ? AutofillHints.newPassword : AutofillHints.password],
                      onFieldSubmitted: (_) => _submit(),
                      validator: (v) => (v ?? '').length >= 8 ? null : l10n.passwordRule,
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(_message!, style: const TextStyle(color: Palette.accent)),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_signingUp ? l10n.signUp : l10n.signIn),
                    ),
                    TextButton(
                      onPressed: () => setState(() {
                        _signingUp = !_signingUp;
                        _message = null;
                      }),
                      child: Text(_signingUp ? l10n.haveAccount : l10n.needAccount),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => ref.read(repositoryProvider).signInWithProvider('google'),
                      child: Text(l10n.continueWithGoogle),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () => ref.read(repositoryProvider).signInWithProvider('apple'),
                      child: Text(l10n.continueWithApple),
                    ),
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 24),
                    Text(l10n.visitByHandle, style: const TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _handle,
                            decoration: InputDecoration(hintText: l10n.handleHint, prefixText: '@'),
                            onSubmitted: (_) => _visit(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: _visit, child: Text(l10n.go)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageSwitch extends ConsumerWidget {
  const _LanguageSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    return Align(
      alignment: Alignment.centerRight,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: 'ko', label: Text('KO')),
          ButtonSegment(value: 'en', label: Text('EN')),
        ],
        selected: {locale.languageCode},
        onSelectionChanged: (s) => ref.read(localeProvider.notifier).set(Locale(s.first)),
      ),
    );
  }
}
