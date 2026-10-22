import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'app_theme.dart';
import 'screens/main_shell.dart';
import 'widgets/splash_screen.dart';

class TimetableApp extends StatelessWidget {
  const TimetableApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    return MaterialApp(
      title: '重外小助手',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(
        themeColor: state.settings.themeColor,
        timetableBackground: state.timetableBackground,
        platformBrightness: platformBrightness,
      ),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: state.booting ? const SplashScreen() : const MainShell(),
    );
  }
}
