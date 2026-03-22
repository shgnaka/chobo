import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/local_db/chobo_records.dart';
import '../../data/service/suggestion_service.dart';

class AutocompleteTextField extends StatefulWidget {
  const AutocompleteTextField({
    super.key,
    required this.fieldType,
    this.transactionType,
    required this.onSelected,
    this.suggestionService,
    this.placeholder,
    this.initialValue,
    this.enabled = true,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.maxSuggestions = 10,
  });

  final SelectionFieldType fieldType;
  final String? transactionType;
  final void Function(String value) onSelected;
  final SuggestionService? suggestionService;
  final String? placeholder;
  final String? initialValue;
  final bool enabled;
  final Duration debounceDuration;
  final int maxSuggestions;

  @override
  State<AutocompleteTextField> createState() => _AutocompleteTextFieldState();
}

class _AutocompleteTextFieldState extends State<AutocompleteTextField> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();

  Timer? _debounceTimer;
  List<SuggestionResult> _suggestions = [];
  bool _isLoading = false;
  bool _showSuggestions = false;
  int _highlightedIndex = -1;

  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialValue ?? '';
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _debounceTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus && _suggestions.isNotEmpty) {
      _showSuggestionsOverlay();
    } else {
      _hideSuggestionsOverlay();
    }
  }

  void _onTextChanged(String value) {
    _debounceTimer?.cancel();

    if (value.isEmpty) {
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _highlightedIndex = -1;
      });
      _removeOverlay();
      return;
    }

    _debounceTimer = Timer(widget.debounceDuration, () {
      _loadSuggestions(value);
    });
  }

  Future<void> _loadSuggestions(String query) async {
    setState(() => _isLoading = true);

    try {
      final suggestions = widget.suggestionService != null
          ? await widget.suggestionService!.getSuggestions(
              fieldType: widget.fieldType,
              query: query,
              transactionType: widget.transactionType,
              limit: widget.maxSuggestions,
              debounce: false,
            )
          : <SuggestionResult>[];

      if (mounted) {
        setState(() {
          _suggestions = suggestions;
          _isLoading = false;
          _showSuggestions = suggestions.isNotEmpty;
          _highlightedIndex = suggestions.isNotEmpty ? 0 : -1;
        });

        if (_showSuggestions && _focusNode.hasFocus) {
          _showSuggestionsOverlay();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
    }
  }

  void _showSuggestionsOverlay() {
    if (_suggestions.isEmpty && !_isLoading) return;

    _removeOverlay();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: _buildSuggestionsList(),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideSuggestionsOverlay() {
    _removeOverlay();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Widget _buildSuggestionsList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 250),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _suggestions.length,
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          final isHighlighted = index == _highlightedIndex;

          return InkWell(
            onTap: () => _selectSuggestion(suggestion),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: isHighlighted ? Theme.of(context).hoverColor : null,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          suggestion.displayText,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        if (suggestion.subtitle != null)
                          Text(
                            suggestion.subtitle!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  Icon(
                    _getSourceIcon(suggestion.source),
                    size: 16,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getSourceIcon(SuggestionSource source) {
    return switch (source) {
      SuggestionSource.recent => Icons.history,
      SuggestionSource.frequent => Icons.trending_up,
      SuggestionSource.smart => Icons.auto_awesome,
      SuggestionSource.search => Icons.search,
      SuggestionSource.template => Icons.bookmark,
    };
  }

  void _selectSuggestion(SuggestionResult suggestion) {
    _controller.text = suggestion.value;
    _hideSuggestionsOverlay();
    widget.onSelected(suggestion.value);
    widget.suggestionService?.recordSelection(
      fieldType: widget.fieldType,
      value: suggestion.value,
      transactionType: widget.transactionType,
    );
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        enabled: widget.enabled,
        decoration: InputDecoration(
          hintText: widget.placeholder,
          suffixIcon: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : null,
        ),
        onChanged: _onTextChanged,
        onTap: () {
          if (_suggestions.isNotEmpty) {
            _showSuggestionsOverlay();
          }
        },
      ),
    );
  }
}
