import 'dart:io';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import '../data/receipt_database.dart';
import '../data/receipt_repository.dart';
import '../settings/app_settings.dart';

// ── Currency catalogue ────────────────────────────────────────────────────────
typedef _Currency = ({String code, String name, String symbol});

const _kCurrencies = <_Currency>[
  (code: 'USD', name: 'US Dollar',             symbol: r'$'),
  (code: 'EUR', name: 'Euro',                   symbol: '€'),
  (code: 'GBP', name: 'British Pound',          symbol: '£'),
  (code: 'JPY', name: 'Japanese Yen',           symbol: '¥'),
  (code: 'CNY', name: 'Chinese Yuan',           symbol: '¥'),
  (code: 'INR', name: 'Indian Rupee',           symbol: '₹'),
  (code: 'CAD', name: 'Canadian Dollar',        symbol: r'CA$'),
  (code: 'AUD', name: 'Australian Dollar',      symbol: r'A$'),
  (code: 'CHF', name: 'Swiss Franc',            symbol: 'Fr'),
  (code: 'KRW', name: 'South Korean Won',       symbol: '₩'),
  (code: 'SGD', name: 'Singapore Dollar',       symbol: r'S$'),
  (code: 'HKD', name: 'Hong Kong Dollar',       symbol: r'HK$'),
  (code: 'NOK', name: 'Norwegian Krone',        symbol: 'kr'),
  (code: 'SEK', name: 'Swedish Krona',          symbol: 'kr'),
  (code: 'DKK', name: 'Danish Krone',           symbol: 'kr'),
  (code: 'NZD', name: 'New Zealand Dollar',     symbol: r'NZ$'),
  (code: 'MXN', name: 'Mexican Peso',           symbol: r'MX$'),
  (code: 'BRL', name: 'Brazilian Real',         symbol: r'R$'),
  (code: 'ZAR', name: 'South African Rand',     symbol: 'R'),
  (code: 'RUB', name: 'Russian Ruble',          symbol: '₽'),
  (code: 'TRY', name: 'Turkish Lira',           symbol: '₺'),
  (code: 'AED', name: 'UAE Dirham',             symbol: 'د.إ'),
  (code: 'THB', name: 'Thai Baht',              symbol: '฿'),
  (code: 'IDR', name: 'Indonesian Rupiah',      symbol: 'Rp'),
  (code: 'MYR', name: 'Malaysian Ringgit',      symbol: 'RM'),
  (code: 'PHP', name: 'Philippine Peso',        symbol: '₱'),
  (code: 'VND', name: 'Vietnamese Dong',        symbol: '₫'),
  (code: 'PLN', name: 'Polish Zloty',           symbol: 'zł'),
  (code: 'CZK', name: 'Czech Koruna',           symbol: 'Kč'),
  (code: 'HUF', name: 'Hungarian Forint',       symbol: 'Ft'),
];

String _currencyLabel(String symbol) {
  final match = _kCurrencies.firstWhere(
    (c) => c.symbol == symbol,
    orElse: () => (code: '', name: 'Custom', symbol: symbol),
  );
  return match.name.isNotEmpty ? '${match.symbol}  ·  ${match.name}' : symbol;
}

// ── Screen ────────────────────────────────────────────────────────────────────
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _currencySymbol;
  late ThemeMode _themeMode;
  late String _dateFormat;
  late bool _compactMode;
  late bool _biometricEnabled;
  String? _version;
  int? _receiptCount;
  int? _photoCount;
  int? _dbSizeBytes;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _currencySymbol = AppSettings.instance.currencySymbol;
    _themeMode      = AppSettings.instance.themeNotifier.value;
    _dateFormat     = AppSettings.instance.dateFormat;
    _compactMode    = AppSettings.instance.compactMode;
    _biometricEnabled = AppSettings.instance.biometricEnabled;
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = '${info.version}+${info.buildNumber}');
    });
    _loadStorageStats();
  }

  // ── Handlers ─────────────────────────────────────────────────────────────

  // ── Storage stats ─────────────────────────────────────────────────────────

  Future<void> _loadStorageStats() async {
    final receipts = await ReceiptDatabase.instance.readAllReceipts();
    int dbSize = 0;
    try {
      final dbPath = await getDatabasesPath();
      final file = File(p.join(dbPath, 'receipts.db'));
      if (await file.exists()) dbSize = await file.length();
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _receiptCount = receipts.length;
      _photoCount = receipts.where((r) => r.photoUrl != null).length;
      _dbSizeBytes = dbSize;
    });
  }

  String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Export all ────────────────────────────────────────────────────────────

  Future<void> _exportAll() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final receipts = await ReceiptDatabase.instance.readAllReceipts();
      if (receipts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No receipts to export.')));
        }
        return;
      }
      final buf = StringBuffer()
        ..writeln('Title,Date,Amount,Category,Notes');
      for (final r in receipts) {
        final t = r.title.replaceAll('"', '""');
        final n = r.notes.replaceAll('"', '""');
        final c = (r.category ?? '').replaceAll('"', '""');
        buf.writeln('"$t","${r.date}",${r.amount},"$c","$n"');
      }
      await Share.share(
        buf.toString(),
        subject: 'All receipts (${receipts.length} items)',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _onThemeChanged(ThemeMode mode) async {
    await AppSettings.instance.setThemeMode(mode);
    if (mounted) setState(() => _themeMode = mode);
  }

  Future<void> _openCurrencyPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E2A4A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CurrencyPickerSheet(current: _currencySymbol),
    );
    if (picked == null || !mounted) return;
    await AppSettings.instance.setCurrencySymbol(picked);
    setState(() => _currencySymbol = picked);
  }

  Future<void> _onDateFormatChanged(String format) async {
    await AppSettings.instance.setDateFormat(format);
    if (mounted) setState(() => _dateFormat = format);
  }

  Future<void> _onCompactChanged(bool value) async {
    await AppSettings.instance.setCompactMode(value);
    if (mounted) setState(() => _compactMode = value);
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
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Clear',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ReceiptRepository.instance.clearCache();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local cache cleared.')));
  }

  Future<void> _onBiometricChanged(bool value) async {
    final auth = LocalAuthentication();
    if (!await auth.isDeviceSupported()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Biometric authentication is not available on this device.')));
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          children: [
            // ── Appearance ───────────────────────────────────────────────
            _SectionLabel('Appearance'),
            const SizedBox(height: 8),
            _SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Theme',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.brightness_auto)),
                      ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode)),
                      ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode)),
                    ],
                    selected: {_themeMode},
                    onSelectionChanged: (s) => _onThemeChanged(s.first),
                  ),
                ],
              ),
            ),

            // ── Display ──────────────────────────────────────────────────
            const SizedBox(height: 28),
            _SectionLabel('Display'),
            const SizedBox(height: 8),

            // Currency
            _SettingsCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Currency',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                subtitle: Text(
                  _currencyLabel(_currencySymbol),
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
                trailing: const Icon(Icons.chevron_right,
                    color: Colors.white38),
                onTap: _openCurrencyPicker,
              ),
            ),
            const SizedBox(height: 10),

            // Date format
            _SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Date format',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'MM/DD/YYYY', label: Text('M/D/Y')),
                      ButtonSegment(
                          value: 'DD/MM/YYYY', label: Text('D/M/Y')),
                      ButtonSegment(
                          value: 'YYYY-MM-DD', label: Text('Y-M-D')),
                    ],
                    selected: {_dateFormat},
                    onSelectionChanged: (s) => _onDateFormatChanged(s.first),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Preview: ${AppSettings.instance.formatDate(DateTime.now().toIso8601String())}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Compact mode
            _SettingsCard(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Compact list',
                    style: TextStyle(color: Colors.white, fontSize: 15)),
                subtitle: const Text(
                  'Tighter spacing in the receipt list',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                value: _compactMode,
                onChanged: _onCompactChanged,
              ),
            ),

            // ── Data ─────────────────────────────────────────────────────
            const SizedBox(height: 28),
            _SectionLabel('Data'),
            const SizedBox(height: 8),

            // Export all
            _SettingsCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Export all receipts',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  'Share full history as a CSV file',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.ios_share_outlined,
                        color: Colors.white54),
                onTap: _exportAll,
              ),
            ),
            const SizedBox(height: 10),

            // Storage usage
            _SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Storage usage',
                      style: TextStyle(color: Colors.white, fontSize: 15)),
                  const SizedBox(height: 12),
                  _StatRow(
                    icon: Icons.receipt_outlined,
                    label: 'Receipts',
                    value: _receiptCount != null ? '$_receiptCount' : '—',
                  ),
                  const SizedBox(height: 8),
                  _StatRow(
                    icon: Icons.photo_outlined,
                    label: 'Photos attached',
                    value: _photoCount != null ? '$_photoCount' : '—',
                  ),
                  const SizedBox(height: 8),
                  _StatRow(
                    icon: Icons.storage_outlined,
                    label: 'Local cache size',
                    value: _dbSizeBytes != null
                        ? _fmtSize(_dbSizeBytes!)
                        : '—',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Clear cache
            _SettingsCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Clear local cache',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text(
                  'Removes cached receipts from this device only',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing:
                    const Icon(Icons.delete_outline, color: Colors.redAccent),
                onTap: _confirmClearCache,
              ),
            ),

            // ── Security ─────────────────────────────────────────────────
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

            // ── About ────────────────────────────────────────────────────
            const SizedBox(height: 28),
            _SectionLabel('About'),
            const SizedBox(height: 8),
            _SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Paperless',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    _version != null ? 'Version $_version' : 'Version —',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Open-source licences',
                    style: TextStyle(color: Colors.white)),
                trailing: const Icon(Icons.chevron_right,
                    color: Colors.white38),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Paperless',
                  applicationVersion: _version,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Currency picker bottom sheet ─────────────────────────────────────────────
class _CurrencyPickerSheet extends StatefulWidget {
  final String current;
  const _CurrencyPickerSheet({required this.current});

  @override
  State<_CurrencyPickerSheet> createState() => _CurrencyPickerSheetState();
}

class _CurrencyPickerSheetState extends State<_CurrencyPickerSheet> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_Currency> get _filtered => _query.isEmpty
      ? _kCurrencies
      : _kCurrencies
          .where((c) =>
              c.name.toLowerCase().contains(_query) ||
              c.code.toLowerCase().contains(_query) ||
              c.symbol.contains(_query))
          .toList();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _search,
              autofocus: false,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search currency…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search, color: Colors.white38),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Colors.white38),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        })
                    : null,
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.07),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
              onChanged: (v) =>
                  setState(() => _query = v.toLowerCase()),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: scrollCtrl,
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final c = _filtered[i];
                final selected = c.symbol == widget.current;
                return ListTile(
                  leading: Text(c.symbol,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 20)),
                  title: Text(c.name,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(c.code,
                      style: const TextStyle(
                          color: Colors.white54, fontSize: 12)),
                  trailing: selected
                      ? const Icon(Icons.check,
                          color: Colors.deepPurpleAccent)
                      : null,
                  onTap: () => Navigator.of(context).pop(c.symbol),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.white38),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label,
              style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        Text(value,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
      ],
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
      style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600),
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
