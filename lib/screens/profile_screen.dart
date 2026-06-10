import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _uploadedPhotoUrl; // overrides user.photoURL after a fresh upload

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
    setState(() => _saving = true);
    try {
      await FirebaseAuth.instance.currentUser!.updateDisplayName(name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Display name updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update name: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
              const SizedBox(height: 32),
              Text(
                'Email',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  user.email ?? '—',
                  style: const TextStyle(color: Colors.white70, fontSize: 15),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Display name',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
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
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _saving ? null : _saveName,
                style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save name'),
              ),
              if (isPasswordProvider) ...[
                const SizedBox(height: 32),
                const Divider(color: Colors.white12),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: _sendPasswordReset,
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: const Text('Send password reset email'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
