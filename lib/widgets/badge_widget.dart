import 'package:flutter/material.dart';
import '../models/badge_definition.dart';

/// Renders a single badge as a circle with an icon or custom asset image.
/// When [earned] is false the badge is rendered at low opacity (locked state).
class BadgeWidget extends StatelessWidget {
  final BadgeDefinition badge;
  final bool earned;
  final double size;

  const BadgeWidget({
    super.key,
    required this.badge,
    this.earned = true,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: earned ? 1.0 : 0.28,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: badge.color.withValues(alpha: 0.18),
          border: Border.all(
            color: badge.color.withValues(alpha: earned ? 0.65 : 0.3),
            width: 2,
          ),
        ),
        child: badge.assetPath != null
            ? _assetOrIcon(badge.assetPath!)
            : _iconWidget(),
      ),
    );
  }

  Widget _assetOrIcon(String path) {
    return ClipOval(
      child: Image.asset(
        path,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _iconWidget(),
      ),
    );
  }

  Widget _iconWidget() {
    return Icon(
      badge.icon,
      size: size * 0.44,
      color: badge.color,
    );
  }
}
