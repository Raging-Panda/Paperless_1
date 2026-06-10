import 'package:flutter/material.dart';
import '../settings/app_settings.dart';
import 'auth_gate.dart';
import 'onboarding_screen.dart';

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppSettings.instance.onboardingComplete) {
      return const OnboardingScreen();
    }
    return const AuthGate();
  }
}
