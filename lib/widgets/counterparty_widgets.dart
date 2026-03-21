import 'package:chobo/app/chobo_providers.dart';
import 'package:chobo/data/local_db/chobo_records.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CounterpartyAutocomplete extends ConsumerStatefulWidget {
  const CounterpartyAutocomplete({
    super.key,
    required this.controller,
    this.onSelected,
  });

  final TextEditingController controller;
  final ValueChanged<ChoboCounterpartyRecord?>? onSelected;

  @override
  ConsumerState<CounterpartyAutocomplete> createState() =>
      _CounterpartyAutocompleteState();
}

class _CounterpartyAutocompleteState
    extends ConsumerState<CounterpartyAutocomplete> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  List<ChoboCounterpartyRecord> _suggestions = [];
  bool _isLoading = false;
  ChoboCounterpartyRecord? _selectedCounterparty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    _removeOverlay();
    super.dispose();
  }

  void _onTextChanged() {
    _search(widget.controller.text);
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _selectedCounterparty = null;
      });
      _removeOverlay();
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await ref
          .read(counterpartyRepositoryProvider)
          .searchCounterparties(query);
      setState(() {
        _suggestions = results;
        _isLoading = false;
      });
      _showOverlay();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: _buildSuggestionsList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          '一致する相手先がありません',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _suggestions.length,
      itemBuilder: (context, index) {
        final counterparty = _suggestions[index];
        return ListTile(
          dense: true,
          title: Text(counterparty.rawName),
          subtitle: counterparty.rawName != counterparty.normalizedName
              ? Text(
                  counterparty.normalizedName,
                  style: Theme.of(context).textTheme.bodySmall,
                )
              : null,
          onTap: () => _selectCounterparty(counterparty),
        );
      },
    );
  }

  void _selectCounterparty(ChoboCounterpartyRecord counterparty) {
    widget.controller.text = counterparty.rawName;
    setState(() {
      _selectedCounterparty = counterparty;
      _suggestions = [];
    });
    _removeOverlay();
    widget.onSelected?.call(counterparty);
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: '相手先',
          suffixIcon: _selectedCounterparty != null
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    widget.controller.clear();
                    setState(() {
                      _selectedCounterparty = null;
                    });
                    widget.onSelected?.call(null);
                  },
                )
              : null,
        ),
        onTap: () {
          if (_suggestions.isNotEmpty) {
            _showOverlay();
          } else if (widget.controller.text.isNotEmpty) {
            _search(widget.controller.text);
          }
        },
        onFieldSubmitted: (value) async {
          if (value.isNotEmpty && _selectedCounterparty == null) {
            final counterparty = await ref
                .read(counterpartyRepositoryProvider)
                .getOrCreateCounterparty(rawName: value);
            setState(() {
              _selectedCounterparty = counterparty;
            });
            widget.onSelected?.call(counterparty);
          }
        },
      ),
    );
  }
}
