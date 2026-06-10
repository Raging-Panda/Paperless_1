import 'package:flutter/material.dart';
import '../models/receipt.dart';
import '../settings/app_settings.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  late Map<String, double> _budgets;

  @override
  void initState() {
    super.initState();
    _budgets = Map.from(AppSettings.instance.budgets);
  }

  Future<void> _editBudget(String category) async {
    final current = _budgets[category];
    final controller = TextEditingController(
      text: current != null ? current.toStringAsFixed(2) : '',
    );

    final result = await showDialog<double?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A4A),
        title: Text('Budget for $category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            prefixText: AppSettings.instance.currencySymbol,
            hintText: 'Monthly limit',
            hintStyle: const TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          if (current != null)
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(0.0), // 0 = clear
              child: const Text('Remove', style: TextStyle(color: Colors.redAccent)),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null), // null = cancel
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final v = double.tryParse(controller.text.trim());
              Navigator.of(ctx).pop(v ?? -1);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (result == null) return; // cancelled

    final limit = result <= 0 ? null : result;
    await AppSettings.instance.setBudget(category, limit);
    if (mounted) {
      setState(() {
        _budgets = Map.from(AppSettings.instance.budgets);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sym = AppSettings.instance.currencySymbol;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Monthly Budgets')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Set a monthly spending limit for each category. '
                'Limits are shown as progress bars in Analytics.',
                style: const TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
              ),
            ),
            ...kCategories.map((cat) {
              final limit = _budgets[cat];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => _editBudget(cat),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: limit != null
                            ? Colors.deepPurpleAccent.withValues(alpha: 0.4)
                            : Colors.white12,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            cat,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                          ),
                        ),
                        if (limit != null) ...[
                          Text(
                            '$sym${limit.toStringAsFixed(2)} / mo',
                            style: const TextStyle(
                                color: Colors.deepPurpleAccent, fontSize: 14),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.edit_outlined,
                              size: 16, color: Colors.white38),
                        ] else
                          const Text('No limit',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 14)),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
