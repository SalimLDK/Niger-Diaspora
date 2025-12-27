import 'package:flutter/material.dart';

/// A standardized, reusable search bar widget with consistent styling.
///
/// Features:
/// - Consistent design across all screens
/// - Theme-aware colors
/// - Clear button when text is entered
/// - Customizable hint text
/// - Optional autofocus
///
/// Usage:
/// ```dart
/// StandardSearchBar(
///   controller: _searchController,
///   hintText: 'Rechercher...',
///   onChanged: (value) => setState(() => _query = value),
/// )
/// ```
class StandardSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const StandardSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
  });

  @override
  State<StandardSearchBar> createState() => _StandardSearchBarState();
}

class _StandardSearchBarState extends State<StandardSearchBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      setState(() {}); // Rebuild when text changes to show/hide clear button
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: widget.controller,
        autofocus: widget.autofocus,
        textInputAction: widget.textInputAction ?? TextInputAction.search,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              widget.controller.text.isNotEmpty
                  ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      widget.controller.clear();
                      widget.onClear?.call();
                      widget.onChanged?.call('');
                    },
                  )
                  : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

/// A compact search bar for use in app bars.
///
/// This variant is optimized for placement in AppBar actions or title.
class CompactSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  const CompactSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
      ),
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}
