import 'package:flutter/material.dart';

/// Immutable definition of a badge. The [assetPath] is optional — if provided
/// and the asset file exists, the image is used; otherwise [icon] is the fallback.
class BadgeDefinition {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color color;

  /// Optional asset path, e.g. "assets/badges/first_scan.png".
  /// Drop image files here when custom artwork is ready — no code changes needed.
  final String? assetPath;

  const BadgeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.assetPath,
  });
}

/// Central catalogue of every badge in the app.
class BadgeCatalogue {
  BadgeCatalogue._();

  static const List<BadgeDefinition> all = [
    BadgeDefinition(
      id: 'first_scan',
      name: 'First Scan',
      description: 'Save your very first receipt.',
      icon: Icons.qr_code_scanner,
      color: Color(0xFF7C4DFF),
      assetPath: 'assets/badges/first_scan.png',
    ),
    BadgeDefinition(
      id: 'streak_7',
      name: '7-Day Streak',
      description: 'Scan receipts 7 days in a row.',
      icon: Icons.local_fire_department,
      color: Color(0xFFFF6D00),
      assetPath: 'assets/badges/streak_7.png',
    ),
    BadgeDefinition(
      id: 'streak_30',
      name: '30-Day Streak',
      description: 'Scan receipts 30 days in a row.',
      icon: Icons.whatshot,
      color: Color(0xFFD50000),
      assetPath: 'assets/badges/streak_30.png',
    ),
    BadgeDefinition(
      id: 'explorer',
      name: 'Explorer',
      description: 'Scan receipts from 10 different stores.',
      icon: Icons.explore,
      color: Color(0xFF00BCD4),
      assetPath: 'assets/badges/explorer.png',
    ),
    BadgeDefinition(
      id: 'loyal_regular',
      name: 'Loyal Regular',
      description: 'Scan at the same store 10 times.',
      icon: Icons.store,
      color: Color(0xFF3F51B5),
      assetPath: 'assets/badges/loyal_regular.png',
    ),
    BadgeDefinition(
      id: 'eco_warrior',
      name: 'Eco Warrior',
      description: 'Save 100 paperless receipts.',
      icon: Icons.eco,
      color: Color(0xFF4CAF50),
      assetPath: 'assets/badges/eco_warrior.png',
    ),
    BadgeDefinition(
      id: 'budget_master',
      name: 'Budget Master',
      description: 'Stay under budget for a full month.',
      icon: Icons.account_balance_wallet,
      color: Color(0xFFFFC107),
      assetPath: 'assets/badges/budget_master.png',
    ),
    BadgeDefinition(
      id: 'green_giant',
      name: 'Green Giant',
      description: 'Save 50 receipts — over 400g of paper avoided.',
      icon: Icons.forest,
      color: Color(0xFF8BC34A),
      assetPath: 'assets/badges/green_giant.png',
    ),
  ];

  static BadgeDefinition? findById(String id) {
    try {
      return all.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}
