import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'screens/root_gate.dart';
import 'settings/app_settings.dart';
import 'widgets/offline_banner.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await AppSettings.instance.load();
  await NotificationService.instance.init();
  runApp(const MyApp());
}

// Smooth horizontal slide on all platforms — matches iOS feel.
final _pageTransitions = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
  },
);

final _lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: Colors.transparent,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.deepPurple,
    elevation: 0,
    foregroundColor: Colors.white,
  ),
  pageTransitionsTheme: _pageTransitions,
);

final _darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: Colors.deepPurple,
    brightness: Brightness.dark,
  ),
  scaffoldBackgroundColor: Colors.transparent,
  appBarTheme: const AppBarTheme(
    backgroundColor: Color.fromRGBO(49, 27, 146, 0.84),
    elevation: 0,
    foregroundColor: Colors.white,
  ),
  pageTransitionsTheme: _pageTransitions,
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppSettings.instance.themeNotifier,
      builder: (context, themeMode, _) => MaterialApp(
        title: 'Paperless',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: _lightTheme,
        darkTheme: _darkTheme,
        builder: (context, child) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Stack(
            children: [
              // Adaptive background gradient
              AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [
                            Color(0xFF070B18),
                            Color(0xFF131A35),
                            Color(0xFF1E2A4A),
                          ]
                        : const [
                            Color(0xFFF5F0FF),
                            Color(0xFFEDE8FF),
                            Color(0xFFE8F2FF),
                          ],
                  ),
                ),
              ),
              // Decorative glow circles
              Positioned(
                top: -80,
                right: -80,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isDark
                          ? const [Color(0x338C6CFF), Colors.transparent]
                          : const [Color(0x228C6CFF), Colors.transparent],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -60,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: isDark
                          ? const [Color(0x2438B6FF), Colors.transparent]
                          : const [Color(0x1A38B6FF), Colors.transparent],
                    ),
                  ),
                ),
              ),
              if (child != null) Positioned.fill(child: child),
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(bottom: false, child: OfflineBanner()),
              ),
            ],
          );
        },
        home: const RootGate(),
      ),
    );
  }
}
