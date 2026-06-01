import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF5C6BC0);
  static const Color primaryLight = Color(0xFF8E99F3);
  static const Color primaryDark = Color(0xFF26418F);

  static const Color background = Color(0xFFF8F9FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F9);

  static const Color income = Color(0xFF43A047);
  static const Color incomeLight = Color(0xFFE8F5E9);
  static const Color expense = Color(0xFFE53935);
  static const Color expenseLight = Color(0xFFFFEBEE);
  static const Color transfer = Color(0xFF1E88E5);
  static const Color transferLight = Color(0xFFE3F2FD);
  static const Color savings = Color(0xFFFB8C00);
  static const Color savingsLight = Color(0xFFFFF3E0);

  static const Color textPrimary = Color(0xFF1A1D2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color textInverse = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  static const Color cashWallet = Color(0xFF43A047);
  static const Color bkashWallet = Color(0xFFE91E8C);
  static const Color savingsWallet = Color(0xFFFB8C00);

  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFE65100);
  static const Color shadow = Color(0x0D000000);
  static const Color overlay = Color(0x80000000);

  /// 12 visually distinct colors for analytics charts.
  static const List<Color> chartPalette = [
    Color(0xFF5C6BC0), // Indigo
    Color(0xFFE53935), // Red
    Color(0xFF43A047), // Green
    Color(0xFFFB8C00), // Amber
    Color(0xFF8E24AA), // Purple
    Color(0xFF00ACC1), // Cyan
    Color(0xFFFF7043), // Deep Orange
    Color(0xFF1E88E5), // Blue
    Color(0xFF7CB342), // Light Green
    Color(0xFF6D4C41), // Brown
    Color(0xFF00897B), // Teal
    Color(0xFFAD1457), // Pink
  ];
}