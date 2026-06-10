import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../data/receipt_repository.dart';
import '../settings/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _currencies = [r'$', '€', '£', '¥', '₹'];
  late String _selectedCurrency;
  String? _version;
  late bool _biometricEnabled;

  @override
  void initState() {
    super.initState();
    _selectedCurrency = AppSettings.instance.currencySymbol;
    _biometricEnabled = AppSettings.instance.biometricEnabled;
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version}+${info.buildNumber}');
    });
  }

  Future<void> _onCurrencyChanged(String? symbol) async {
    if (symbol == null) return;
    await AppSettings.instance.setCurrencySymbol(symbol);
    setState(() => _selectedCurrency = symbol);
  }

  Future<void> _confirmClearCache() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A4A),
        title: const Text('Clear local cache?'),
        content: const Text(
          'Cached receipts will be removed from this device. '
          'Your data in the cloud is not affected.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ReceiptRepository.instance.clearCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local cache cleared.')),
    );
  }

  Future<void> _onBiometricChanged(bool value) async {
    final auth = LocalAuthentication();
    final supported = await auth.isDeviceSupported();
    if (!supported) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Biometric authentication is not available on this device.')),
      );
      return;
    }
    if (value) {
      final ok = await auth.authenticate(
        localizedReason: 'Confirm your identity to enable biometric lock',
        options: const AuthenticationOptions(biometricOnly: false),
      );
      if (!ok) return;
    }
    await AppSettings.instance.setBiometricEnabled(value);
    if (mounted) setState(() => _biometricEnabled = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            _SectionLabel('Display'),
            const SizedBox(height: 8),
            _SettingsCard(
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Currency symbol', style: TextStyle(color: Colors.white, fontSize: 15)),
                  ),
                  DropdownButton<String>(
                    value: _selectedCurrency,
                    dropdownColor: const Color(0xFF1E2A4A),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    underline: const SizedBox(),
                    items: _currencies
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: _onCurrencyChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            _SectionLabel('Data'),
            const SizedBox(height: 8),
            _SettingsCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Clear local cache', style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  'Removes cached receipts from this device only',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onTap: _confirmClearCache,
              ),
            ),
            const SizedBox(height: 28),
            _SectionLabel('Security'),
            const SizedBox(height: 8),
            _SettingsCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Biometric lock',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                subtitle: const Text(
                  'Require fingerprint or face ID to open app',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                value: _biometricEnabled,
                onChanged: _onBiometricChanged,
              ),
            ),
            const SizedBox(height: 28),
            _SectionLabel('About'),
            const SizedBox(height: 8),
            _SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Paperless', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    _version != null ? 'Version $_version' : 'Version —',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w600),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;
  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}
