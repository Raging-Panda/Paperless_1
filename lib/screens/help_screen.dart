import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      q: 'How do I scan a receipt?',
      a: 'From the home screen tap Scan, then choose QR Code or NFC. '
          'Point your camera at a QR code or hold the device near an NFC tag. '
          'A confirmation sheet will appear — tap Save to History.',
    ),
    (
      q: 'How do I view my receipt history?',
      a: 'Tap View Receipts on the home screen. '
          'Cached receipts load instantly; the list then refreshes automatically from the cloud.',
    ),
    (
      q: 'How do I delete a receipt?',
      a: 'In Receipt History, swipe any receipt card to the left to reveal the delete action. '
          'The receipt is removed from both this device and the cloud.',
    ),
    (
      q: 'Are my receipts backed up?',
      a: 'Yes. Every receipt is saved to Firestore automatically when you scan it. '
          'Sign in on any device to access the same history.',
    ),
    (
      q: 'What happens when I sign out?',
      a: 'The local cache is cleared from this device. '
          'Your receipts remain safely stored in the cloud and reload the next time you sign in.',
    ),
    (
      q: 'How do I change my display name?',
      a: 'Tap the profile icon in the top-right corner of the home screen, '
          'edit the Display name field, then tap Save name.',
    ),
    (
      q: 'How do I change the currency symbol?',
      a: 'Open the drawer (swipe from the left or tap the menu icon), '
          'go to Settings, and choose a currency symbol under Display.',
    ),
    (
      q: 'How do I reset my password?',
      a: 'On the sign-in screen tap Forgot password? and enter your email. '
          'You can also trigger a reset from the Profile screen.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Help')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: Colors.white54, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Tap a question to expand the answer.',
                      style: TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            ..._faqs.map(
              (item) => _FaqTile(question: item.q, answer: item.a),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            collapsedBackgroundColor: Colors.white.withValues(alpha: 0.06),
            backgroundColor: Colors.white.withValues(alpha: 0.09),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.white12),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: Colors.white24),
            ),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(
              question,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
            ),
            iconColor: Colors.white54,
            collapsedIconColor: Colors.white38,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  answer,
                  style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
