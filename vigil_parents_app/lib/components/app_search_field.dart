import 'package:flutter/material.dart';
import 'package:vigil_parents_app/core/appColor/app_color.dart';

/// A clean, consistent search field used across the feature screens.
class AppSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String value;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const AppSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.value,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
        suffixIcon: value.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                color: AppColors.textSecondary,
                onPressed: onClear,
              ),
        isDense: true,
        filled: true,
        fillColor: AppColors.scaffold,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.2),
        ),
      ),
    );
  }
}
