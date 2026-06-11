import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/receipt_repository.dart';
import '../models/receipt.dart';
import '../services/recurring_service.dart';
import '../services/gamification_service.dart';
import '../widgets/level_up_dialog.dart';
import '../widgets/badge_unlock_dialog.dart';
import '../models/gamification_profile.dart';
import '../models/quest_definition.dart';
import '../services/quest_service.dart';
import '../models/challenge.dart';
import '../services/challenge_service.dart';
import '../settings/app_settings.dart';

class AddReceiptScreen extends StatefulWidget {
  final Receipt? initial;
  const AddReceiptScreen({super.key, this.initial});

  @override
  State<AddReceiptScreen> createState() => _AddReceiptScreenState();
}

class _AddReceiptScreenState extends State<AddReceiptScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  String? _localPhotoPath;
  bool _isRecurring = false;
  String _recurringInterval = 'monthly';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final r = widget.initial;
    if (r != null) {
      _titleController.text = r.title;
      _amountController.text = r.amount.toStringAsFixed(2);
      _notesController.text = r.notes;
      _selectedDate = DateTime.tryParse(r.date) ?? DateTime.now();
      _selectedCategory = r.category;
      _localPhotoPath = null; // photos not pre-filled on edit (URL exists in receipt)
      _isRecurring = r.isRecurring;
      _recurringInterval = r.recurringInterval ?? 'monthly';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickPhoto() async {
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
              leading: const Icon(Icons.camera_alt_outlined, color: Colors.white),
              title: const Text('Take photo', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: Colors.white),
              title: const Text('Choose from gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;
    final file = await ImagePicker().pickImage(source: choice, imageQuality: 85);
    if (file != null && mounted) setState(() => _localPhotoPath = file.path);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final Receipt saved;
      if (widget.initial != null) {
        final updated = widget.initial!.copyWith(
          title: _titleController.text.trim(),
          date: _selectedDate.toIso8601String(),
          amount: double.parse(_amountController.text.trim()),
          notes: _notesController.text.trim(),
          category: _selectedCategory,
          isRecurring: _isRecurring,
          recurringInterval: _isRecurring ? _recurringInterval : null,
          nextDueDate: _isRecurring
              ? RecurringService.nextDue(_selectedDate, _recurringInterval).toIso8601String()
              : null,
        );
        saved = await ReceiptRepository.instance.update(uid, updated, localPhotoPath: _localPhotoPath);
      } else {
        final receipt = Receipt(
          title: _titleController.text.trim(),
          date: _selectedDate.toIso8601String(),
          amount: double.parse(_amountController.text.trim()),
          notes: _notesController.text.trim(),
          category: _selectedCategory,
          isRecurring: _isRecurring,
          recurringInterval: _isRecurring ? _recurringInterval : null,
          nextDueDate: _isRecurring
              ? RecurringService.nextDue(_selectedDate, _recurringInterval).toIso8601String()
              : null,
        );
        saved = await ReceiptRepository.instance.save(uid, receipt, localPhotoPath: _localPhotoPath);
        final xpResult = await GamificationService.instance.onReceiptSaved(uid, saved);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(xpResult.message)),
          );
          await showLevelUpIfNeeded(context, xpResult);
          await showBadgeUnlocksIfAny(context, xpResult.newlyUnlockedBadges);
          final completedQuests = await QuestService.instance
              .onReceiptSaved(uid, saved, xpResult.updatedProfile);
          if (completedQuests.isNotEmpty && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Quest complete: ${completedQuests.first.title} +${completedQuests.first.xpReward} XP'),
              ),
            );
          }
          final completedChallenges =
              await ChallengeService.instance.onReceiptSaved(uid, saved);
          if (completedChallenges.isNotEmpty && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    'Challenge complete! ${completedChallenges.first.title} — check Challenges for your reward.'),
              ),
            );
          }
        }
      }
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save receipt: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate =
        AppSettings.instance.formatDate(_selectedDate.toIso8601String());

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(widget.initial != null ? 'Edit Receipt' : 'Add Receipt')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Merchant / Title',
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a merchant name' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixIcon: const Icon(Icons.attach_money),
                    prefixText: AppSettings.instance.currencySymbol,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter an amount';
                    final n = double.tryParse(v.trim());
                    if (n == null || n < 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      formattedDate,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes_outlined),
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                // Photo picker
                GestureDetector(
                  onTap: _pickPhoto,
                  child: Container(
                    height: _localPhotoPath != null ? 180 : 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: _localPhotoPath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(_localPhotoPath!), fit: BoxFit.cover,
                                width: double.infinity),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo_outlined, color: Colors.white54),
                              SizedBox(width: 10),
                              Text('Add photo', style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                  ),
                ),
                // Show existing photo URL if editing and no new local photo selected
                if (_localPhotoPath == null && widget.initial?.photoUrl != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      widget.initial!.photoUrl!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                // Recurring toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Recurring receipt',
                            style: TextStyle(color: Colors.white, fontSize: 15)),
                        subtitle: const Text('Auto-create on a schedule',
                            style: TextStyle(color: Colors.white54, fontSize: 12)),
                        value: _isRecurring,
                        onChanged: (v) => setState(() => _isRecurring = v),
                      ),
                      if (_isRecurring)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              const Text('Repeat every',
                                  style: TextStyle(color: Colors.white70, fontSize: 14)),
                              const SizedBox(width: 16),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(value: 'weekly', label: Text('Week')),
                                  ButtonSegment(value: 'monthly', label: Text('Month')),
                                ],
                                selected: {_recurringInterval},
                                onSelectionChanged: (s) =>
                                    setState(() => _recurringInterval = s.first),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Category (optional)',
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: kCategories.map((cat) {
                    final selected = _selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat),
                      selected: selected,
                      onSelected: (on) =>
                          setState(() => _selectedCategory = on ? cat : null),
                      selectedColor: Colors.deepPurple,
                      backgroundColor: Colors.white.withValues(alpha: 0.06),
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontSize: 13,
                      ),
                      side: BorderSide(
                        color: selected ? Colors.deepPurpleAccent : Colors.white24,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(widget.initial != null ? 'Save Changes' : 'Save Receipt'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
