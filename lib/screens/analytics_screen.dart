import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../data/receipt_database.dart';
import '../data/receipt_repository.dart';
import '../models/receipt.dart';
import '../settings/app_settings.dart';
import 'budget_screen.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  List<Receipt> _receipts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final cached = await ReceiptDatabase.instance.readAllReceipts();
    if (!mounted) return;
    setState(() { _receipts = cached; _loading = false; });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final synced = await ReceiptRepository.instance.syncFromFirestore(uid);
      if (mounted) setState(() => _receipts = synced);
    } catch (_) {}
  }

  // ── Computed properties ──────────────────────────────────────────────────

  double get _totalAllTime =>
      _receipts.fold(0.0, (s, r) => s + r.amount);

  double get _totalThisMonth {
    final now = DateTime.now();
    return _receipts.where((r) {
      final d = DateTime.tryParse(r.date);
      return d != null && d.year == now.year && d.month == now.month;
    }).fold(0.0, (s, r) => s + r.amount);
  }

  /// Returns totals for the last 6 calendar months, oldest first.
  List<({String label, double total})> get _last6Months {
    final now = DateTime.now();
    const abbr = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                   'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return List.generate(6, (i) {
      final month = DateTime(now.year, now.month - 5 + i);
      final key =
          '${month.year}-${month.month.toString().padLeft(2, '0')}';
      final total = _receipts.where((r) {
        final d = DateTime.tryParse(r.date);
        return d != null && d.year == month.year && d.month == month.month;
      }).fold(0.0, (s, r) => s + r.amount);
      return (label: abbr[month.month - 1], total: total);
    });
  }

  /// Returns category totals sorted by amount descending.
  List<({String category, double total})> get _categoryTotals {
    final map = <String, double>{};
    for (final r in _receipts) {
      final cat = r.category ?? 'Uncategorised';
      map[cat] = (map[cat] ?? 0) + r.amount;
    }
    final list = map.entries
        .map((e) => (category: e.key, total: e.value))
        .toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    return list;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _fmt(double amount) =>
      '${AppSettings.instance.currencySymbol}${amount.toStringAsFixed(2)}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Set budgets',
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const BudgetScreen()))
                .then((_) => setState(() {})), // refresh after returning
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _receipts.isEmpty
              ? const Center(
                  child: Text(
                    'No receipts yet.',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 20),
                  children: [
                    _summaryRow(),
                    const SizedBox(height: 28),
                    _sectionLabel('Monthly Spending'),
                    const SizedBox(height: 12),
                    _barChart(),
                    const SizedBox(height: 28),
                    _sectionLabel('Spending by Category'),
                    const SizedBox(height: 12),
                    _categoryList(),
                  ],
                ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: Colors.white38,
          fontSize: 11,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _summaryRow() {
    return Row(
      children: [
        Expanded(child: _SummaryCard(label: 'This month', value: _fmt(_totalThisMonth))),
        const SizedBox(width: 12),
        Expanded(child: _SummaryCard(label: 'All time', value: _fmt(_totalAllTime))),
      ],
    );
  }

  Widget _barChart() {
    final months = _last6Months;
    final maxY = months.map((m) => m.total).fold(0.0, (a, b) => a > b ? a : b);
    final chartMax = maxY == 0 ? 10.0 : maxY * 1.25;

    return Container(
      height: 200,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: BarChart(
        BarChartData(
          maxY: chartMax,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                _fmt(rod.toY),
                const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final i = value.toInt();
                  if (i < 0 || i >= months.length) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      months[i].label,
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: Colors.white10, strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(months.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: months[i].total,
                  color: Colors.deepPurpleAccent,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  Widget _categoryList() {
    final cats = _categoryTotals;
    if (cats.isEmpty) {
      return const Text('No categorised receipts.',
          style: TextStyle(color: Colors.white38));
    }
    final grandTotal = cats.fold(0.0, (s, c) => s + c.total);
    final budgets = AppSettings.instance.budgets;
    return Column(
      children: cats.map((c) {
        final spendPct = grandTotal > 0 ? c.total / grandTotal : 0.0;
        final budget = budgets[c.category];
        final hasBudget = budget != null && budget > 0;
        final budgetPct = hasBudget ? (c.total / budget!).clamp(0.0, 2.0) : 0.0;
        final isOver = hasBudget && c.total > budget!;
        final isNear = hasBudget && budgetPct >= 0.75 && !isOver;
        Color barColor = Colors.deepPurpleAccent;
        if (isOver) barColor = Colors.redAccent;
        else if (isNear) barColor = Colors.orangeAccent;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isOver
                    ? Colors.redAccent.withValues(alpha: 0.5)
                    : Colors.white12,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(c.category,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 14)),
                    ),
                    Text(_fmt(c.total),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 14)),
                    const SizedBox(width: 8),
                    if (hasBudget)
                      Text(
                        isOver
                            ? '+${_fmt(c.total - budget!)} over'
                            : '${_fmt(budget! - c.total)} left',
                        style: TextStyle(
                          color: isOver
                              ? Colors.redAccent
                              : isNear
                                  ? Colors.orangeAccent
                                  : Colors.white38,
                          fontSize: 12,
                        ),
                      )
                    else
                      Text('${(spendPct * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: hasBudget
                        ? budgetPct.clamp(0.0, 1.0)
                        : spendPct,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(barColor),
                  ),
                ),
                if (hasBudget)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Budget: ${_fmt(budget!)} / mo',
                          style: const TextStyle(
                              color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
