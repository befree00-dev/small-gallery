import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../data/models.dart';
import '../l10n/app_localizations.dart';
import '../state/providers.dart';
import '../theme.dart';

extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  String get lang => Localizations.localeOf(this).languageCode;

  void toast(String message) =>
      ScaffoldMessenger.of(this)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message)));
}

/// A user-facing sentence for an error thrown by the repository.
String errorText(AppLocalizations l10n, Object error) {
  if (error is AppException) {
    return switch (error.code) {
      'handle_taken' || 'handle_reserved' => l10n.handleTaken,
      'quota_exceeded' => l10n.quotaExceeded,
      'comments_closed' => l10n.commentsClosed,
      'file_too_large' => l10n.fileTooLarge,
      'unsupported_image' => l10n.unsupportedImage,
      'not_found' => l10n.galleryNotFound,
      _ => l10n.somethingWrong,
    };
  }
  return l10n.somethingWrong;
}

/// Loading, error-with-retry and data states for an AsyncValue.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.builder, this.onRetry, this.dark = false});

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback? onRetry;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(errorText(context.l10n, e),
                textAlign: TextAlign.center, style: TextStyle(color: dark ? Palette.darkInk : Palette.ink)),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(onPressed: onRetry, child: Text(context.l10n.retry)),
            ],
          ]),
        ),
      ),
    );
  }
}

/// An artwork image from the public bucket, with a quiet placeholder while it loads.
class ArtworkImage extends ConsumerWidget {
  const ArtworkImage({super.key, required this.path, required this.semanticLabel, this.fit = BoxFit.cover});

  final String path;
  final String semanticLabel;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(repositoryProvider).imageUrl(path);
    return Image.network(
      url,
      fit: fit,
      semanticLabel: semanticLabel,
      frameBuilder: (context, child, frame, sync) => sync || frame != null
          ? child
          : const ColoredBox(color: Color(0xFFE8E5DD), child: SizedBox.expand()),
      errorBuilder: (context, _, _) => const ColoredBox(
        color: Color(0xFFE8E5DD),
        child: Center(child: Icon(Icons.image_not_supported_outlined, color: Palette.muted)),
      ),
    );
  }
}

String visibilityLabel(AppLocalizations l10n, Audience v) => switch (v) {
      Audience.public => l10n.visibilityPublic,
      Audience.unlisted => l10n.visibilityUnlisted,
      Audience.private => l10n.visibilityPrivate,
    };

/// Where the web gallery is deployed. Set at build time:
///   --dart-define=SITE_URL=https://your-site.vercel.app
const siteUrl = String.fromEnvironment('SITE_URL', defaultValue: 'https://smallgallery.app');

/// The site address without scheme, for display: "your-site.vercel.app".
final siteHost = Uri.parse(siteUrl).host;

/// Address visitors open in a browser. The web gallery serves it.
String publicGalleryUrl(String handle) => '$siteUrl/@$handle';

/// Wide layouts (desktop windows, tablets) use a navigation rail instead of a bottom bar.
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;
