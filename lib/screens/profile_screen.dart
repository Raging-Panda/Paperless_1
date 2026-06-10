import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';
import '../data/receipt_database.dart';
import '../data/receipt_repository.dart';
import '../settings/app_settings.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;
  bool _nameDirty = false;
  bool _uploadingAvatar = false;
  String? _uploadedPhotoUrl;

  // Quick stats
  int? _receiptCount;
  double? _monthlySpend;
  int? _categoryCount;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    final currentName = user?.displayName ?? '';
    _nameController.text = currentName;
    _nameController.addListener(() {
      final dirty = _nameController.text.trim() != currentName;
      if (dirty != _nameDirty) setState(() => _nameDirty = dirty);
    });
    _loadStats();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final receipts = await ReceiptDatabase.instance.readAllReceipts();
    final now = DateTime.now();
    final spend = receipts.where((r) {
      final d = DateTime.tryParse(r.date);
      return d != null && d.year == now.year && d.month == now.month;
    }).fold(0.0, (s, r) => s + r.amount);
    final cats =
        receipts.where((r) => r.category != null).map((r) => r.category!).toSet();
    if (mounted) {
      setState(() {
        _receiptCount = receipts.length;
        _monthlySpend = spend;
        _categoryCount = cats.length;
      });
    }
  }

  String? get _effectivePhotoUrl =>
      _uploadedPhotoUrl ?? FirebaseAuth.instance.currentUser?.photoURL;

  Future<void> _pickAvatar() async {
    final choice = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E2A4A),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined,
                  color: Colors.white),
              title: const Text('Take photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined,
                  color: Colors.white),
              title: const Text('Choose from gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            if (_effectivePhotoUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                title: const Text('Remove photo',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _removeAvatar();
                },
              ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    final file = await ImagePicker().pickImage(
        source: choice, imageQuality: 85, maxWidth: 512);
    if (file == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref =
          FirebaseStorage.instance.ref('users/$uid/profile/avatar.jpg');
      await ref.putFile(File(file.path));
      final url = await ref.getDownloadURL();
      await FirebaseAuth.instance.currentUser!.updatePhotoURL(url);
      if (mounted) setState(() => _uploadedPhotoUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _uploadingAvatar = true);
    try {
      await FirebaseAuth.instance.currentUser!.updatePhotoURL(null);
      if (mounted) setState(() => _uploadedPhotoUrl = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to remove photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  String _initials(User user) {
    final name = user.displayName?.trim();
    if (name != null && name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return name[0].toUpperCase();
    }
    final email = user.email ?? '';
    return email.isNotEmpty ? email[0].toUpperCase() : '?';
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name cannot be empty.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await FirebaseAuth.instance.currentUser!.updateDisplayName(name);
      if (!mounted) return;
      setState(() => _nameDirty = false);
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Display name updated.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to update name: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendVerification() async {
    try {
      await FirebaseAuth.instance.currentUser!.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to send: $e')));
    }
  }

  Future<void> _showChangeEmailDialog() async {
    final ctrl = TextEditingController();
    final newEmail = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A4A),
        title: const Text('Change email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A verification link will be sent to the new address. '
              'The change takes effect after you click it.',
              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'New email address',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              child: const Text('Send link')),
        ],
      ),
    );
    ctrl.dispose();
    if (newEmail == null || newEmail.isEmpty || !mounted) return;
    try {
      await FirebaseAuth.instance.currentUser!
          .verifyBeforeUpdateEmail(newEmail);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Verification link sent to $newEmail.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _signOut() async {
    await ReceiptRepository.instance.clearCache();
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A4A),
        title: const Text('Delete account?'),
        content: const Text(
          'All your data will be permanently deleted. '
          'This cannot be undone.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete account',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ReceiptRepository.instance.clearCache();
      await FirebaseAuth.instance.currentUser!.delete();
      // AuthGate stream fires → LoginScreen
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final msg = e.code == 'requires-recent-login'
          ? 'Please sign out and sign back in before deleting your account.'
          : e.message ?? 'Failed to delete account.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = FirebaseAuth.instance.currentUser?.email;
    if (email == null) return;
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset email sent to $email.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reset email: $e')),
      );
    }
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
              color: Colors.white38,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final isPasswordProvider = user.providerData.any((p) => p.providerId == 'password');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: SizedBox(
                  width: 112,
                  height: 112,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Avatar
                      GestureDetector(
                        onTap: _pickAvatar,
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: Colors.deepPurple,
                          backgroundImage: _effectivePhotoUrl != null
                              ? NetworkImage(_effectivePhotoUrl!)
                              : null,
                          child: _effectivePhotoUrl == null
                              ? Text(
                                  _initials(user),
                                  style: const TextStyle(
                                      fontSize: 36,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                      ),
                      // Camera button — bottom right
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _pickAvatar,
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: Colors.deepPurpleAccent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: Colors.black26, width: 2),
                            ),
                            child: _uploadingAvatar
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white))
                                : const Icon(Icons.camera_alt,
                                    size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                      // Provider badge — top right
                      Positioned(
                        top: 0,
                        right: 0,
                        child: _ProviderBadge(
                            providers: user.providerData),
                      ),
                    ],
                  ),
                ),
              ),
              // ── Quick stats ──────────────────────────────────────────
              const SizedBox(height: 28),
              Row(
                children: [
                  _StatCard(
                    value: _receiptCount != null ? '$_receiptCount' : '—',
                    label: 'Receipts',
                    icon: Icons.receipt_outlined,
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    value: _monthlySpend != null
                        ? '${AppSettings.instance.currencySymbol}${_monthlySpend!.toStringAsFixed(0)}'
                        : '—',
                    label: 'This month',
                    icon: Icons.calendar_today_outlined,
                  ),
                  const SizedBox(width: 10),
                  _StatCard(
                    value: _categoryCount != null ? '$_categoryCount' : '—',
                    label: 'Categories',
                    icon: Icons.label_outline,
                  ),
                ],
              ),

              // ── Profile ──────────────────────────────────────────────
              const SizedBox(height: 32),
              _sectionLabel('Profile'),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Display name',
                  labelStyle: const TextStyle(color: Colors.white54),
                  hintText: 'Your name',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: (_saving || !_nameDirty) ? null : _saveName,
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save name'),
              ),

              // ── Account ───────────────────────────────────────────────
              const SizedBox(height: 28),
              _sectionLabel('Account'),
              const SizedBox(height: 10),
              _InfoCard(children: [
                // Email + verification badge
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Email',
                              style: TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 2),
                          Text(user.email ?? '—',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    user.emailVerified
                        ? _Chip(
                            label: 'Verified',
                            icon: Icons.check_circle,
                            color: Colors.green,
                          )
                        : GestureDetector(
                            onTap: _sendVerification,
                            child: _Chip(
                              label: 'Verify',
                              icon: Icons.warning_amber_rounded,
                              color: Colors.orange,
                            ),
                          ),
                  ],
                ),
                const _Divider(),
                // Member since
                _InfoRow(
                  label: 'Member since',
                  value: user.metadata.creationTime != null
                      ? AppSettings.instance
                          .formatDate(user.metadata.creationTime!.toIso8601String())
                      : '—',
                ),
                const _Divider(),
                // Last sign-in
                _InfoRow(
                  label: 'Last sign-in',
                  value: user.metadata.lastSignInTime != null
                      ? AppSettings.instance.formatDate(
                          user.metadata.lastSignInTime!.toIso8601String())
                      : '—',
                ),
              ]),

              // ── Security ─────────────────────────────────────────────
              const SizedBox(height: 28),
              _sectionLabel('Security'),
              const SizedBox(height: 10),
              if (isPasswordProvider) ...[
                OutlinedButton(
                  onPressed: _showChangeEmailDialog,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  child: const Text('Change email'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _sendPasswordReset,
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48)),
                  child: const Text('Send password reset email'),
                ),
                const SizedBox(height: 10),
              ],
              OutlinedButton(
                onPressed: _signOut,
                style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48)),
                child: const Text('Sign out'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: _deleteAccount,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                ),
                child: const Text('Delete account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Reusable widgets ────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  const _StatCard({required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: Colors.deepPurpleAccent),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 13)),
          ),
          Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _Chip({required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(color: Colors.white12, height: 1, thickness: 0.5);
  }
}

class _ProviderBadge extends StatelessWidget {
  final List<UserInfo> providers;
  const _ProviderBadge({required this.providers});

  @override
  Widget build(BuildContext context) {
    final isGoogle = providers.any((p) => p.providerId == 'google.com');
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black12, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))
        ],
      ),
      child: isGoogle
          ? const Text('G',
              style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  height: 1))
          : const Icon(Icons.email_outlined, size: 11, color: Colors.blueGrey),
    );
  }
}
