import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../settings/app_settings.dart';

class BiometricGate extends StatefulWidget {
  final Widget child;
  const BiometricGate({super.key, required this.child});

  @override
  State<BiometricGate> createState() => _BiometricGateState();
}

class _BiometricGateState extends State<BiometricGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _authenticating = false;
  final _auth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (AppSettings.instance.biometricEnabled) {
      _locked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!AppSettings.instance.biometricEnabled) return;
    if (state == AppLifecycleState.paused) {
      setState(() => _locked = true);
    } else if (state == AppLifecycleState.resumed && _locked) {
      _authenticate();
    }
  }

  Future<void> _authenticate() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        setState(() { _locked = false; _authenticating = false; });
        return;
      }
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock Paperless',
        biometricOnly: false,
      );
      if (mounted) setState(() { _locked = !ok; _authenticating = false; });
    } catch (_) {
      if (mounted) setState(() { _locked = false; _authenticating = false; });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline, size: 64, color: Colors.white54),
            const SizedBox(height: 24),
            const Text(
              'Paperless is locked',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _authenticating ? null : _authenticate,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Unlock'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(180, 52),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
