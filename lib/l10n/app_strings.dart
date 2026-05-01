// lib/l10n/app_strings.dart
//
// Central i18n engine for KrishiMitra (Flutter-native, no extra packages).
//
// Usage in a ConsumerWidget:
//   final tr = ref.watch(trProvider);
//   Text(tr('crop_advisor'))
//
// Or via BuildContext extension (when ProviderScope is an ancestor):
//   Text(context.t('submit'))

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/providers/language_provider.dart';
import 'app_en.dart';
import 'app_te.dart';
import 'app_hi.dart';
import 'app_kn.dart';

// ─── Translation registry ─────────────────────────────────────────────────────

const _translations = <String, Map<String, String>>{
  'English': appEn,
  'Telugu':  appTe,
  'Hindi':   appHi,
  'Kannada': appKn,
};

// ─── Typedef ──────────────────────────────────────────────────────────────────

/// A function that takes a translation key and returns the localised string.
typedef Tr = String Function(String key);

// ─── Core lookup ──────────────────────────────────────────────────────────────

class AppStrings {
  AppStrings._();

  /// Returns a [Tr] function bound to [language].
  /// Fallback chain: chosen language → English → key itself.
  static Tr of(String language) {
    final map      = _translations[language] ?? appEn;
    final fallback = appEn;
    return (key) => map[key] ?? fallback[key] ?? key;
  }
}

// ─── Riverpod provider ────────────────────────────────────────────────────────

/// Watch this provider to get a [Tr] function that auto-rebuilds on language change.
///
/// ```dart
/// final tr = ref.watch(trProvider);
/// Text(tr('submit'))
/// ```
final trProvider = Provider<Tr>((ref) {
  final langAsync = ref.watch(languageProvider);
  final lang = langAsync.value ?? 'English';
  return AppStrings.of(lang);
});

// ─── BuildContext extension ────────────────────────────────────────────────────

extension AppStringsX on BuildContext {
  /// Translate [key] using the current language from the nearest [ProviderScope].
  /// Requires a [ProviderScope] ancestor (already present in main.dart).
  String t(String key) {
    // Read directly from the container attached to this BuildContext.
    // Works in both StatelessWidget and StatefulWidget builds.
    try {
      final container = ProviderScope.containerOf(this, listen: false);
      final lang = container.read(languageProvider).value ?? 'English';
      return AppStrings.of(lang)(key);
    } catch (_) {
      return appEn[key] ?? key;
    }
  }
}

