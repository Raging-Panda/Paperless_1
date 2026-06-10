import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:nfc_manager/nfc_manager.dart';
import '../data/receipt_repository.dart';
import '../models/receipt.dart';
import '../services/recurring_service.dart';
import '../settings/app_settings.dart';
import '../widgets/loading_dialog.dart';
import '../widgets/receipt_detail_row.dart';
import '../widgets/scan_option_button.dart';
import 'analytics_screen.dart';
import 'budget_screen.dart';
import 'help_screen.dart';
import 'ocr_scanner_screen.dart';
import 'profile_screen.dart';
import 'qr_scanner_screen.dart';
import 'receipt_list_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    RecurringService.processOverdue();
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void _showScanOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2A4A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Choose Scan Method',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ScanOptionButton(
                    icon: Icons.qr_code_scanner,
                    label: 'QR Code',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _startQrScan(context);
                    },
                  ),
                  ScanOptionButton(
                    icon: Icons.nfc,
                    label: 'NFC',
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _startNfcScan(context);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ScanOptionButton(
                icon: Icons.document_scanner_outlined,
                label: 'Camera OCR',
                onTap: () {
                  Navigator.of(ctx).pop();
                  _startOcrScan(context);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startQrScan(BuildContext context) async {
    final raw = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (raw == null || !mounted) return;
    final receipt = _parseReceiptPayload(raw);
    if (receipt != null) {
      // ignore: use_build_context_synchronously
      await _showReceiptConfirmation(this.context, receipt);
    } else {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Could not read receipt data from QR code.')),
      );
    }
  }

  Future<void> _startNfcScan(BuildContext context) async {
    final availability = await NfcManager.instance.checkAvailability();
    if (!mounted) return;
    if (availability != NfcAvailability.available) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('NFC is not available on this device.')),
      );
      return;
    }

    // ignore: use_build_context_synchronously
    showDialog(
      context: this.context,
      barrierDismissible: true,
      builder: (ctx) => PopScope(
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) NfcManager.instance.stopSession();
        },
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E2A4A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          title: const Text('NFC Scan', style: TextStyle(color: Colors.white)),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.nfc, size: 72, color: Colors.white70),
              SizedBox(height: 16),
              Text(
                'Hold your device near an NFC terminal...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                NfcManager.instance.stopSession();
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    NfcManager.instance.startSession(
      onDiscovered: (NfcTag tag) async {
        String? text;
        try {
          final ndef = Ndef.from(tag);
          if (ndef != null) {
            final msg = ndef.cachedMessage ?? await ndef.read();
            text = _extractNdefText(msg);
          }
        } catch (_) {}

        await NfcManager.instance.stopSession();
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        Navigator.of(this.context).pop();

        if (text != null) {
          final receipt = _parseReceiptPayload(text);
          if (receipt != null && mounted) {
            // ignore: use_build_context_synchronously
            await _showReceiptConfirmation(this.context, receipt);
          } else if (mounted) {
            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(this.context).showSnackBar(
              const SnackBar(content: Text('Could not read receipt data from NFC tag.')),
            );
          }
        } else if (mounted) {
          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(this.context).showSnackBar(
            const SnackBar(content: Text('No readable data found on NFC tag.')),
          );
        }
      },
    );
  }

  Future<void> _startOcrScan(BuildContext context) async {
    final receipt = await Navigator.of(context).push<Receipt>(
      MaterialPageRoute(builder: (_) => const OcrScannerScreen()),
    );
    if (receipt == null || !mounted) return;
    // ignore: use_build_context_synchronously
    await _showReceiptConfirmation(this.context, receipt);
  }

  String? _extractNdefText(NdefMessage message) {
    for (final record in message.records) {
      final payload = record.payload;
      if (payload.isEmpty) continue;
      try {
        final typeStr = String.fromCharCodes(record.type);
        if (typeStr == 'T') {
          final langLen = payload[0] & 0x3F;
          return utf8.decode(payload.sublist(1 + langLen));
        }
        if (typeStr == 'U') {
          return utf8.decode(payload.sublist(1));
        }
        return utf8.decode(payload);
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Receipt? _parseReceiptPayload(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return Receipt(
        title: map['title'] as String? ?? 'Scanned Receipt',
        date: map['date'] as String? ?? DateTime.now().toIso8601String(),
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        notes: map['notes'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _showReceiptConfirmation(BuildContext context, Receipt receipt) async {
    final date = DateTime.tryParse(receipt.date);
    final formattedDate = date != null
        ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
        : receipt.date;

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF1E2A4A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Save Receipt?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 20),
              ReceiptDetailRow(label: 'Merchant', value: receipt.title),
              ReceiptDetailRow(label: 'Amount', value: '${AppSettings.instance.currencySymbol}${receipt.amount.toStringAsFixed(2)}'),
              ReceiptDetailRow(label: 'Date', value: formattedDate),
              if (receipt.notes.isNotEmpty) ReceiptDetailRow(label: 'Notes', value: receipt.notes),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  Navigator.of(ctx).pop(true);
                },
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Save to History'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Discard'),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && mounted) {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      try {
        await ReceiptRepository.instance.save(uid, receipt);
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(this.context).showSnackBar(
          const SnackBar(content: Text('Receipt saved to history.')),
        );
      } catch (_) {
        if (!mounted) return;
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save receipt.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _retrySave(uid, receipt),
            ),
          ),
        );
      }
    }
  }

  Future<void> _retrySave(String uid, Receipt receipt) async {
    try {
      await ReceiptRepository.instance.save(uid, receipt);
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Receipt saved to history.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(this.context).showSnackBar(
        const SnackBar(content: Text('Save failed. Check your connection and try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Paperless'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle),
            onPressed: () => _openProfile(context),
            tooltip: 'Profile',
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.deepPurple),
                child: Text(
                  'Menu',
                  style: TextStyle(color: Colors.white, fontSize: 24),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.help_outline),
                title: const Text('Help'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HelpScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_wallet_outlined),
                title: const Text('Budgets'),
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BudgetScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await ReceiptRepository.instance.clearCache();
                  await GoogleSignIn().signOut();
                  await FirebaseAuth.instance.signOut();
                  // AuthGate stream fires → LoginScreen
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SizedBox(),
              Column(
                children: [
                  const Text(
                    'Ready to scan documents?',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () => _showScanOptions(context),
                    icon: const Icon(Icons.qr_code_scanner, size: 28),
                    label: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                      child: Text('Scan', style: TextStyle(fontSize: 18)),
                    ),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      minimumSize: const Size(200, 62),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Center(
                  child: Column(
                    children: [
                      OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const ReceiptListScreen()),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(220, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('View Receipts', style: TextStyle(fontSize: 16)),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
                          );
                        },
                        icon: const Icon(Icons.bar_chart),
                        label: const Text('Analytics', style: TextStyle(fontSize: 16)),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(220, 56),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
