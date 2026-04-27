import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle heading1 = GoogleFonts.nunito(
    fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textPrimary,
  );
  static TextStyle heading2 = GoogleFonts.nunito(
    fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static TextStyle heading3 = GoogleFonts.nunito(
    fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
  );
  static TextStyle body = GoogleFonts.nunito(
    fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
  );
  static TextStyle bodySecondary = GoogleFonts.nunito(
    fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
  );
  static TextStyle label = GoogleFonts.nunito(
    fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary,
    letterSpacing: 0.3,
  );
  static TextStyle money = GoogleFonts.nunito(
    fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  );
  static TextStyle badge = GoogleFonts.nunito(
    fontSize: 11, fontWeight: FontWeight.w600,
  );
}
