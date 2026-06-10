import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/receipt_database.dart';
import '../data/receipt_repository.dart';
import '../models/receipt.dart';
import '../settings/app_settings.dart';
import 'add_receipt_screen.dart';
import 'receipt_detail_screen.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  bool _loading = true;
  bool _syncing = false;
  List<Receipt> _receipts = [];

  final _searchController = TextEditingController();
  String _searchQuery = '';
  DateTime? _filterStart;
  DateTime? _filterEnd;
  SortOrder _sortOrder = AppSettings.instance.sortOrder;
  String? _selectedCategory;

  bool get _filterActive => _filterStart != null || _filterEnd != null;

  List<Receipt> get _filtered {
    final list = _receipts.where((r) {
      if (_searchQuery.isNotEmpty &&
          !r.title.toLowerCase().contains(_searchQuery.toLowerCase())) {
        return false;
      }
      if (_selectedCategory != null && r.category != _selectedCategory) return false;
      final date = DateTime.tryParse(r.date);
      if (date != null) {
        if (_filterStart != null &&
            date.isBefore(DateTime(
                _filterStart!.year, _filterStart!.month, _filterStart!.day))) {
          return false;
        }
        if (_filterEnd != null &&
            date.isAfter(DateTime(
                _filterEnd!.year, _filterEnd!.month, _filterEnd!.day, 23, 59, 59))) {
          return false;
        }
      }
      return true;
    }).toList();
    switch (_sortOrder) {
      case SortOrder.dateDesc:
        list.sort((a, b) => b.date.compareTo(a.date));
      case SortOrder.dateAsc:
        list.sort((a, b) => a.date.compareTo(b.date));
      case SortOrder.amountDesc:
        list.sort((a, b) => b.amount.compareTo(a.amount));
      case SortOrder.amountAsc:
        list.sort((a, b) => a.amount.compareTo(b.amount));
      case SortOrder.merchantAsc:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return list;
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String get _filterLabel {
    if (_filterStart != null && _filterEnd != null) {
      return '${_fmtDate(_filterStart!)} – ${_fmtDate(_filterEnd!)}';
    } else if (_filterStart != null) {
      return 'From ${_fmtDate(_filterStart!)}';
    } else {
      return 'Until ${_fmtDate(_filterEnd!)}';
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text);
    });
    _loadReceipts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReceipts() async {
    // Phase 1: show cached data instantly
    final cached = await ReceiptDatabase.instance.readAllReceipts();
    if (!mounted) return;
    setState(() {
      _receipts = cached;
      _loading = false;
      _syncing = true;
    });

    // Phase 2: sync from Firestore
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final synced = await ReceiptRepository.instance.syncFromFirestore(uid);
      if (!mounted) return;
      setState(() {
        _receipts = synced;
      });
    } catch (_) {
      // offline or error — keep cached data
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _syncReceipts() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final synced = await ReceiptRepository.instance.syncFromFirestore(uid);
      if (!mounted) return;
      setState(() => _receipts = synced);
    } catch (_) {
      // offline — keep current list
    }
  }

  Future<void> _openDetail(Receipt receipt) async {
    final result = await Navigator.of(context).push<dynamic>(
      MaterialPageRoute(builder: (_) => ReceiptDetailScreen(receipt: receipt)),
    );
    if (result == true) {
      setState(() => _receipts.remove(receipt));
    } else if (result is Receipt) {
      setState(() {
        final i = _receipts.indexWhere(
          (r) => (r.firestoreId != null && r.firestoreId == receipt.firestoreId) ||
              (r.id != null && r.id == receipt.id),
        );
        if (i != -1) _receipts[i] = result;
      });
    }
  }

  Future<void> _openAddReceipt() async {
    final added = await Navigator.of(context).push<Receipt>(
      MaterialPageRoute(builder: (_) => const AddReceiptScreen()),
    );
    if (added != null) setState(() => _receipts.insert(0, added));
  }

  Future<void> _deleteReceipt(Receipt receipt) async {
    setState(() => _receipts.remove(receipt));
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await ReceiptRepository.instance.delete(uid, receipt);
    } catch (_) {
      // restore on failure
      if (mounted) setState(() => _receipts.add(receipt));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to delete receipt.')),
        );
      }
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Receipt deleted.')),
    );
  }

  void _openFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E2A4A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _FilterSheet(
        initialStart: _filterStart,
        initialEnd: _filterEnd,
        onApply: (s, e) => setState(() { _filterStart = s; _filterEnd = e; }),
        onClear: () => setState(() { _filterStart = null; _filterEnd = null; }),
      ),
    );
  }

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _monthLabel(String yearMonth) {
    if (yearMonth.isEmpty) return 'Unknown';
    final parts = yearMonth.split('-');
    if (parts.length != 2) return yearMonth;
    final month = int.tryParse(parts[1]);
    if (month == null || month < 1 || month > 12) return yearMonth;
    return '${_monthNames[month - 1]} ${parts[0]}';
  }

  // Flat list for non-date sorts; header + receipts for date sorts.
  List<dynamic> get _groupedItems {
    final filtered = _filtered;
    if (_sortOrder != SortOrder.dateDesc && _sortOrder != SortOrder.dateAsc) {
      return filtered;
    }
    final items = <dynamic>[];
    String? lastMonth;
    for (final r in filtered) {
      final date = DateTime.tryParse(r.date);
      final monthKey = date != null
          ? '${date.year}-${date.month.toString().padLeft(2, '0')}'
          : '';
      if (monthKey != lastMonth) {
        items.add(monthKey);
        lastMonth = monthKey;
      }
      items.add(r);
    }
    return items;
  }

  PopupMenuItem<SortOrder> _sortMenuItem(
      SortOrder value, String label, SortOrder current) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            current == value
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
            size: 18,
            color: current == value ? Colors.deepPurpleAccent : Colors.white38,
          ),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddReceipt,
        tooltip: 'Add receipt',
        child: const Icon(Icons.add),
      ),
      appBar: AppBar(
        title: const Text('Receipt History'),
        actions: [
          PopupMenuButton<SortOrder>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onSelected: (order) async {
              await AppSettings.instance.setSortOrder(order);
              setState(() => _sortOrder = order);
            },
            itemBuilder: (_) => [
              _sortMenuItem(SortOrder.dateDesc,    'Date: newest first',    _sortOrder),
              _sortMenuItem(SortOrder.dateAsc,     'Date: oldest first',    _sortOrder),
              _sortMenuItem(SortOrder.amountDesc,  'Amount: highest first', _sortOrder),
              _sortMenuItem(SortOrder.amountAsc,   'Amount: lowest first',  _sortOrder),
              _sortMenuItem(SortOrder.merchantAsc, 'Merchant: A–Z',         _sortOrder),
            ],
          ),
          IconButton(
            tooltip: 'Filter by date',
            onPressed: _openFilter,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.filter_list),
                if (_filterActive)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.deepPurpleAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _syncing
                ? const LinearProgressIndicator(key: ValueKey('bar'))
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Search by merchant...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: Colors.white38),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white38),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
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
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              if (_filterActive)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, size: 15, color: Colors.white54),
                      const SizedBox(width: 6),
                      Text(_filterLabel,
                          style: const TextStyle(color: Colors.white54, fontSize: 13)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(
                            () { _filterStart = null; _filterEnd = null; }),
                        child: const Icon(Icons.close, size: 15, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: kCategories.map((cat) {
                    final selected = _selectedCategory == cat;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: selected,
                        onSelected: (on) =>
                            setState(() => _selectedCategory = on ? cat : null),
                        selectedColor: Colors.deepPurple,
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : Colors.white54,
                          fontSize: 12,
                        ),
                        side: BorderSide(
                          color: selected ? Colors.deepPurpleAccent : Colors.white12,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _receipts.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.receipt_long, size: 56, color: Colors.white54),
                                const SizedBox(height: 18),
                                const Text(
                                  'No saved receipts yet.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white70, fontSize: 18),
                                ),
                                const SizedBox(height: 24),
                                OutlinedButton.icon(
                                  onPressed: _openAddReceipt,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add receipt'),
                                ),
                              ],
                            ),
                          )
                        : _filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.search_off, size: 48, color: Colors.white38),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No receipts match your search.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white54, fontSize: 16),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _syncReceipts,
                                child: ListView.builder(
                                  itemCount: _groupedItems.length,
                                  itemBuilder: (context, index) {
                                    final item = _groupedItems[index];
                                    if (item is String) {
                                      return _MonthHeader(label: _monthLabel(item));
                                    }
                                    final receipt = item as Receipt;
                                    final date = DateTime.tryParse(receipt.date);
                                    final formattedDate = date != null
                                        ? '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'
                                        : receipt.date;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 12),
                                      child: Dismissible(
                                        key: ValueKey(receipt.firestoreId ?? receipt.id ?? '${receipt.title}-${receipt.date}'),
                                        direction: DismissDirection.endToStart,
                                        onDismissed: (_) {
                                          HapticFeedback.mediumImpact();
                                          _deleteReceipt(receipt);
                                        },
                                        background: Container(
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(right: 20),
                                          decoration: BoxDecoration(
                                            color: Colors.redAccent.withValues(alpha: 0.85),
                                            borderRadius: BorderRadius.circular(16),
                                          ),
                                          child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
                                        ),
                                        child: Card(
                                          color: const Color.fromRGBO(255, 255, 255, 0.08),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          child: ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            onTap: () => _openDetail(receipt),
                                            title: Text(receipt.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            subtitle: Text('$formattedDate · ${receipt.notes}', style: const TextStyle(color: Colors.white70)),
                                            trailing: Text('${AppSettings.instance.currencySymbol}${receipt.amount.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
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

class _MonthHeader extends StatelessWidget {
  final String label;
  const _MonthHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white54,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final void Function(DateTime? start, DateTime? end) onApply;
  final VoidCallback onClear;

  const _FilterSheet({
    required this.initialStart,
    required this.initialEnd,
    required this.onApply,
    required this.onClear,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: _end ?? DateTime.now(),
    );
    if (picked != null) setState(() => _start = picked);
  }

  Future<void> _pickEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end ?? DateTime.now(),
      firstDate: _start ?? DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _end = picked);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Filter by Date',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    label: 'From',
                    value: _start != null ? _fmt(_start!) : null,
                    onTap: _pickStart,
                    onClear: _start != null ? () => setState(() => _start = null) : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateButton(
                    label: 'To',
                    value: _end != null ? _fmt(_end!) : null,
                    onTap: _pickEnd,
                    onClear: _end != null ? () => setState(() => _end = null) : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      widget.onClear();
                      Navigator.of(context).pop();
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_start, _end);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateButton({
    required this.label,
    required this.value,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(color: Colors.white38, fontSize: 11)),
                  Text(
                    value ?? 'Any',
                    style: TextStyle(
                      color: value != null ? Colors.white : Colors.white38,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 16, color: Colors.white38),
              )
            else
              const Icon(Icons.calendar_today_outlined, size: 16, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}
