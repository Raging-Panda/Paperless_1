import 'package:flutter/material.dart';

class QuestDefinition {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int xpReward;

  const QuestDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.xpReward,
  });
}

class QuestCatalogue {
  QuestCatalogue._();

  static const List<QuestDefinition> all = [
    QuestDefinition(
      id: 'welcome',
      title: 'Welcome!',
      description: "You're here! Your paperless journey begins.",
      icon: Icons.waving_hand_outlined,
      color: Color(0xFF7C4DFF),
      xpReward: 20,
    ),
    QuestDefinition(
      id: 'first_scan',
      title: 'First Scan',
      description: 'Save your very first receipt.',
      icon: Icons.qr_code_scanner,
      color: Color(0xFF3F51B5),
      xpReward: 30,
    ),
    QuestDefinition(
      id: 'get_organised',
      title: 'Get Organised',
      description: 'Assign a category to a receipt.',
      icon: Icons.label_outline,
      color: Color(0xFF00BCD4),
      xpReward: 25,
    ),
    QuestDefinition(
      id: 'add_detail',
      title: 'Detail Master',
      description: 'Save a receipt with notes.',
      icon: Icons.edit_note,
      color: Color(0xFF009688),
      xpReward: 25,
    ),
    QuestDefinition(
      id: 'set_a_goal',
      title: 'Set a Goal',
      description: 'Create your first monthly budget.',
      icon: Icons.account_balance_wallet_outlined,
      color: Color(0xFFFFC107),
      xpReward: 25,
    ),
    QuestDefinition(
      id: 'know_your_spending',
      title: 'Know Your Spending',
      description: 'Visit the Analytics screen.',
      icon: Icons.bar_chart,
      color: Color(0xFFFF6D00),
      xpReward: 20,
    ),
    QuestDefinition(
      id: 'build_a_streak',
      title: 'On a Roll',
      description: 'Scan receipts on 2 consecutive days.',
      icon: Icons.local_fire_department,
      color: Color(0xFFD50000),
      xpReward: 40,
    ),
  ];

  static QuestDefinition? findById(String id) {
    try {
      return all.firstWhere((q) => q.id == id);
    } catch (_) {
      return null;
    }
  }
}
