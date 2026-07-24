import 'dart:async';

import 'package:flutter/material.dart';

/// A standardized, reusable search bar widget with consistent styling.
class StandardSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final EdgeInsetsGeometry padding;
  final Duration? debounceDuration;
  final bool isLoading;
  final bool showClearButton;

  const StandardSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.padding = const EdgeInsets.all(16),
    this.debounceDuration,
    this.isLoading = false,
    this.showClearButton = true,
  });

  @override
  State<StandardSearchBar> createState() => _StandardSearchBarState();
}

class _StandardSearchBarState extends State<StandardSearchBar> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _handleChanged(String value) {
    if (widget.debounceDuration == null) {
      widget.onChanged?.call(value);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(widget.debounceDuration!, () {
      widget.onChanged?.call(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showClear =
        widget.showClearButton && widget.controller.text.isNotEmpty;

    return Padding(
      padding: widget.padding,
      child: TextField(
        controller: widget.controller,
        autofocus: widget.autofocus,
        textInputAction: widget.textInputAction ?? TextInputAction.search,
        onChanged: _handleChanged,
        onSubmitted: widget.onSubmitted,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon:
              widget.isLoading
                  ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                  : showClear
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

/// Compact search bar for app bars and map overlays.
class CompactSearchBar extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final bool autofocus;
  final Duration? debounceDuration;
  final bool isLoading;
  final bool showClearButton;

  const CompactSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.autofocus = false,
    this.debounceDuration,
    this.isLoading = false,
    this.showClearButton = true,
  });

  @override
  State<CompactSearchBar> createState() => _CompactSearchBarState();
}

class _CompactSearchBarState extends State<CompactSearchBar> {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _handleChanged(String value) {
    if (widget.debounceDuration == null) {
      widget.onChanged?.call(value);
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(widget.debounceDuration!, () {
      widget.onChanged?.call(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final showClear =
        widget.showClearButton && widget.controller.text.isNotEmpty;

    return TextField(
      controller: widget.controller,
      autofocus: widget.autofocus,
      onChanged: _handleChanged,
      onSubmitted: widget.onSubmitted,
      decoration: InputDecoration(
        hintText: widget.hintText,
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        suffixIcon:
            widget.isLoading
                ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : showClear
                ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () {
                    widget.controller.clear();
                    widget.onClear?.call();
                    widget.onChanged?.call('');
                  },
                )
                : null,
      ),
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}
