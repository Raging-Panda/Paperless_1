import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../models/receipt.dart';

class OcrScannerScreen extends StatefulWidget {
  const OcrScannerScreen({super.key});

  @override
  State<OcrScannerScreen> createState() => _OcrScannerScreenState();
}

class _OcrScannerScreenState extends State<OcrScannerScreen> {
  bool _processing = false;
  String _status = 'Opening camera…';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan());
  }

  Future<void> _scan() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );
    if (image == null) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (!mounted) return;
    setState(() { _processing = true; _status = 'Recognising text…'; });

    try {
      final recognizer = TextRecognizer();
      final inputImage = InputImage.fromFilePath(image.path);
      final result = await recognizer.processImage(inputImage);
      await recognizer.close();
      if (!mounted) return;
      final receipt = _parse(result);
      Navigator.of(context).pop(receipt);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('OCR failed: $e')),
      );
      Navigator.of(context).pop();
    }
  }

  Receipt _parse(RecognizedText recognized) {
    final lines = recognized.blocks
        .expand((b) => b.lines)
        .map((l) => l.text.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final fullText = lines.join('\n').toLowerCase();

    // ── Amount ──────────────────────────────────────────────────────────────
    double amount = 0.0;
    // Look for total/amount keyword first
    final totalRe = RegExp(
        r'(?:total|amount due|grand total|sum)[^\d]*(\d{1,6}[.,]\d{2})',
        caseSensitive: false);
    final totalMatch = totalRe.firstMatch(fullText);
    if (totalMatch != null) {
      amount = double.tryParse(
              totalMatch.group(1)!.replaceAll(',', '.')) ??
          0.0;
    } else {
      // Largest X.XX value in the text
      final amountsRe = RegExp(r'\b(\d{1,6}[.,]\d{2})\b');
      final amounts = amountsRe
          .allMatches(fullText)
          .map((m) => double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0.0)
          .toList()
        ..sort((a, b) => b.compareTo(a));
      if (amounts.isNotEmpty) amount = amounts.first;
    }

    // ── Date ────────────────────────────────────────────────────────────────
    String dateStr = DateTime.now().toIso8601String();
    final dateRe = RegExp(
        r'(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})');
    final dateMatch = dateRe.firstMatch(fullText);
    if (dateMatch != null) {
      try {
        final a = int.parse(dateMatch.group(1)!);
        final b = int.parse(dateMatch.group(2)!);
        var y = int.parse(dateMatch.group(3)!);
        if (y < 100) y += 2000;
        // Assume MM/DD/YYYY; swap if month > 12
        final month = a <= 12 ? a : b;
        final day = a <= 12 ? b : a;
        final d = DateTime(y, month, day);
        if (d.isBefore(DateTime.now().add(const Duration(days: 1)))) {
          dateStr = d.toIso8601String();
        }
      } catch (_) {}
    }

    // ── Merchant ────────────────────────────────────────────────────────────
    // First non-trivial line (length ≥ 3 and not purely numeric/symbols)
    final merchant = lines.firstWhere(
      (l) => l.length >= 3 && RegExp(r'[a-zA-Z]').hasMatch(l),
      orElse: () => 'Scanned Receipt',
    );

    return Receipt(
      title: merchant,
      date: dateStr,
      amount: amount,
      notes: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_processing)
              const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 24),
            Text(
              _status,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
