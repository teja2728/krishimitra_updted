import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kLangKey = 'app_language';
const kSupportedLanguages = ['English', 'Hindi', 'Telugu', 'Kannada'];

class LanguageNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLangKey) ?? 'English';
  }

  Future<void> setLanguage(String lang) async {
    if (!kSupportedLanguages.contains(lang)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLangKey, lang);
    state = AsyncValue.data(lang);
  }
}

final languageProvider =
    AsyncNotifierProvider<LanguageNotifier, String>(() => LanguageNotifier());
