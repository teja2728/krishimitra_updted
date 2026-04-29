import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/app_theme.dart';
import '../app/providers/language_provider.dart';

/// A compact language-selector dropdown for use anywhere in the app.
class LanguageSelector extends ConsumerWidget {
  const LanguageSelector({super.key});

  static const _flags = {
    'English': '🇬🇧',
    'Hindi':   '🇮🇳',
    'Telugu':  '🇮🇳',
    'Kannada': '🇮🇳',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final langAsync = ref.watch(languageProvider);
    final current   = langAsync.value ?? 'English';
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withOpacity(0.07)
            : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.primary.withOpacity(0.30),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: AppTheme.primary),
          dropdownColor: isDark ? const Color(0xFF1E2535) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: kSupportedLanguages.map((lang) {
            return DropdownMenuItem(
              value: lang,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_flags[lang] ?? '🌐',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 6),
                  Text(
                    lang,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (lang) {
            if (lang != null) {
              ref.read(languageProvider.notifier).setLanguage(lang);
            }
          },
        ),
      ),
    );
  }
}
