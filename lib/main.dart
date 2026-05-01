import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app_router.dart';
import 'app/app_theme.dart';
import 'app/providers/language_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const ProviderScope(child: KrishiMitraApp()));
}

// ─── Locale mapping ───────────────────────────────────────────────────────────
const _langToLocale = <String, Locale>{
  'English': Locale('en', 'IN'),
  'Telugu':  Locale('te', 'IN'),
  'Hindi':   Locale('hi', 'IN'),
  'Kannada': Locale('kn', 'IN'),
};

class KrishiMitraApp extends ConsumerWidget {
  const KrishiMitraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch language — rebuilds MaterialApp when user switches language
    final langAsync = ref.watch(languageProvider);
    final lang   = langAsync.value ?? 'English';
    final locale = _langToLocale[lang] ?? const Locale('en', 'IN');

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'KrishiMitra',
      theme:      AppTheme.lightTheme(),
      darkTheme:  AppTheme.darkTheme(),
      themeMode:  ThemeMode.dark,
      locale:     locale,
      routerConfig: appRouter,
    );
  }
}

