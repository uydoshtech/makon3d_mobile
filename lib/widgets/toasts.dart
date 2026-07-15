import "package:flutter/material.dart";

/// Minimal floating toast helpers (success / error / info).
abstract final class Toasts {
  static void showSuccess(BuildContext context, String message) =>
      _show(context, message, const Color(0xFF2E7D32), Icons.check_circle_outline);

  static void showError(BuildContext context, String message) =>
      _show(context, message, const Color(0xFFC62828), Icons.error_outline);

  static void showInfo(BuildContext context, String message) =>
      _show(context, message, const Color(0xFF37474F), Icons.info_outline);

  static void _show(
    BuildContext context,
    String message,
    Color color,
    IconData icon,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: [
              Icon(icon, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}
