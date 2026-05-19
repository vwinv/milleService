import 'dart:async';

import 'package:flutter/material.dart';
import 'package:milleservices/controllers/geocodingController.dart';
import 'package:milleservices/services/sizeConfig.dart';

/// Champ adresse avec autocomplétion via backend (Google Places).
class AddressAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final TextStyle labelStyle;
  final TextStyle textfieldStyle;
  final TextStyle placeholderStyle;
  final String placeholder;
  final double height;
  final double width;
  final Color borderColor;
  final Color fillColor;
  final String? Function(String?)? validator;

  const AddressAutocompleteField({
    super.key,
    required this.controller,
    required this.borderColor,
    required this.fillColor,
    required this.label,
    required this.labelStyle,
    required this.placeholder,
    required this.textfieldStyle,
    required this.placeholderStyle,
    required this.height,
    required this.width,
    this.validator,
  });

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final GeocodingController _geocoding = GeocodingController();
  List<AutocompleteSuggestion> _predictions = [];
  bool _loading = false;
  bool _hasSearched = false;
  Timer? _debounce;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _debounce?.cancel();
      setState(() {
        _predictions = [];
        _hasSearched = false;
        _loading = false;
      });
    } else if (widget.controller.text.trim().length >= 2) {
      _fetchSuggestions(widget.controller.text.trim());
    }
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _predictions = [];
        _hasSearched = false;
        _loading = false;
      });
      return;
    }
    if (trimmed.length < 2) {
      setState(() {
        _predictions = [];
        _hasSearched = false;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchSuggestions(trimmed);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (!_focusNode.hasFocus) return;
    setState(() {
      _loading = true;
      _hasSearched = false;
    });

    final list = await _geocoding.autocomplete(query);

    if (!mounted || !_focusNode.hasFocus) return;
    setState(() {
      _predictions = list;
      _loading = false;
      _hasSearched = true;
    });
  }

  void _onSelectSuggestion(AutocompleteSuggestion suggestion) {
    widget.controller.text = suggestion.displayName;
    setState(() {
      _predictions = [];
      _hasSearched = false;
    });
    _focusNode.unfocus();
  }

  bool get _showSuggestionsPanel {
    if (!_focusNode.hasFocus) return false;
    if (widget.controller.text.trim().length < 2) return false;
    return _loading || _hasSearched;
  }

  Widget _buildSuggestionsPanel() {
    final borderRadius = SizeConfig.blockSizeHorizontal * 10;

    Widget content;
    if (_loading && _predictions.isEmpty) {
      content = Padding(
        padding: EdgeInsets.all(SizeConfig.blockSizeHorizontal * 3),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    } else if (_predictions.isEmpty) {
      content = Padding(
        padding: EdgeInsets.all(SizeConfig.blockSizeHorizontal * 3),
        child: const Text(
          'Aucune adresse trouvée',
          style: TextStyle(color: Colors.grey),
        ),
      );
    } else {
      content = ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: _predictions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final p = _predictions[index];
          return ListTile(
            dense: true,
            title: Text(
              p.displayName,
              style: TextStyle(
                fontSize: SizeConfig.fontSize(
                  SizeConfig.blockSizeHorizontal * 3.2,
                ),
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _onSelectSuggestion(p),
          );
        },
      );
    }

    return Material(
      elevation: 4,
      color: Colors.white,
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(borderRadius),
        bottomRight: Radius.circular(borderRadius),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: content,
      ),
    );
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = widget.height < 48 ? 48.0 : widget.height;
    final borderRadius = SizeConfig.blockSizeHorizontal * 10;
    final showPanel = _showSuggestionsPanel;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.blockSizeHorizontal * 5,
        vertical: SizeConfig.blockSizeVertical * 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: widget.label.isNotEmpty ? SizeConfig.blockSizeVertical * 1 : 0,
        children: [
          if (widget.label.isNotEmpty)
            Text(widget.label, style: widget.labelStyle),
          Container(
            height: effectiveHeight,
            width: widget.width,
            padding: EdgeInsets.only(
              left: widget.label.isNotEmpty
                  ? SizeConfig.blockSizeHorizontal * 5
                  : 0,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: widget.borderColor),
              color: widget.fillColor,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(borderRadius),
                bottom: showPanel ? Radius.zero : Radius.circular(borderRadius),
              ),
            ),
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              style: widget.textfieldStyle,
              decoration: InputDecoration(
                hintText: widget.placeholder,
                border: InputBorder.none,
                hintStyle: widget.placeholderStyle,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              validator: widget.validator,
              onChanged: _onTextChanged,
            ),
          ),
          if (showPanel)
            SizedBox(
              width: widget.width,
              child: _buildSuggestionsPanel(),
            ),
        ],
      ),
    );
  }
}
