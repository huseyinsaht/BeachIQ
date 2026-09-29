import 'package:flutter/material.dart';

/// A full-width rounded, light ("paper") search input with a leading search
/// icon, reusable on any screen that needs city search.
///
/// Pure presentational widget — no network, provider, or repository
/// dependency.
class SearchField extends StatelessWidget {
  const SearchField({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.hintText = 'Enter cities',
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String hintText;

  static const _surfacePaper = Color(0xFFFFFFFF);
  static const _textOnPaper = Color(0xFF2E3057);
  static const _textSecondary = Color(0xFF8B93A6);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _surfacePaper,
        borderRadius: BorderRadius.circular(28),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        style: const TextStyle(color: _textOnPaper),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: _textSecondary),
          prefixIcon: const Icon(Icons.search, color: _textSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
