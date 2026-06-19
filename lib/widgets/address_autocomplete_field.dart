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
  final double? biasLat;
  final double? biasLng;
  final ValueChanged<AddressSelection?>? onSelectionChanged;

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
    this.biasLat,
    this.biasLng,
    this.onSelectionChanged,
  });

  @override
  State<AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<AddressAutocompleteField> {
  final GeocodingController _geocoding = GeocodingController();
  List<AutocompleteSuggestion> _predictions = [];
  bool _loading = false;
  bool _resolvingSelection = false;
  bool _hasSearched = false;
  Timer? _debounce;
  final _focusNode = FocusNode();
  AddressSelection? _selection;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _clearSelection() {
    if (_selection == null) return;
    _selection = null;
    widget.onSelectionChanged?.call(null);
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
    final trimmed = value.trim();
    if (_selection != null && trimmed != _selection!.displayName.trim()) {
      _clearSelection();
    }

    _debounce?.cancel();
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

    final list = await _geocoding.autocomplete(
      query,
      biasLat: widget.biasLat,
      biasLng: widget.biasLng,
    );
    final suggestions = list.isNotEmpty
        ? list
        : await _geocoding.geocodeFallbackSuggestions(query);

    if (!mounted || !_focusNode.hasFocus) return;
    setState(() {
      _predictions = suggestions;
      _loading = false;
      _hasSearched = true;
    });
  }

  Future<void> _onSelectSuggestion(AutocompleteSuggestion suggestion) async {
    final displayName = suggestion.displayName.trim();
    widget.controller.text = displayName;
    setState(() {
      _predictions = [];
      _hasSearched = false;
      _resolvingSelection = true;
    });

    double? lat = suggestion.lat;
    double? lng = suggestion.lng;
    final placeId = suggestion.placeId?.trim();

    if ((lat == null || lng == null) &&
        placeId != null &&
        placeId.isNotEmpty) {
      final coords = await _geocoding.placeDetails(placeId);
      if (coords != null) {
        lat = coords.lat;
        lng = coords.lng;
      }
    }

    if (!mounted) return;

    _selection = AddressSelection(
      displayName: displayName,
      placeId: placeId,
      lat: lat,
      lng: lng,
    );
    widget.onSelectionChanged?.call(_selection);

    setState(() => _resolvingSelection = false);
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
            leading: const Icon(Icons.place_outlined, size: 20),
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
          SizedBox(
            width: widget.width,
            child: TextFormField(
              controller: widget.controller,
              focusNode: _focusNode,
              style: widget.textfieldStyle,
              validator: widget.validator,
              onChanged: _onTextChanged,
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: widget.placeholderStyle,
                filled: true,
                fillColor: widget.fillColor,
                isDense: false,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: widget.label.isNotEmpty
                      ? SizeConfig.blockSizeHorizontal * 5
                      : SizeConfig.blockSizeHorizontal * 3,
                  vertical: 12,
                ),
                constraints: BoxConstraints(minHeight: effectiveHeight),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(borderRadius),
                    bottom: showPanel
                        ? Radius.zero
                        : Radius.circular(borderRadius),
                  ),
                  borderSide: BorderSide(color: widget.borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(borderRadius),
                    bottom: showPanel
                        ? Radius.zero
                        : Radius.circular(borderRadius),
                  ),
                  borderSide: BorderSide(color: widget.borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(borderRadius),
                    bottom: showPanel
                        ? Radius.zero
                        : Radius.circular(borderRadius),
                  ),
                  borderSide: BorderSide(color: widget.borderColor),
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(borderRadius),
                    bottom: showPanel
                        ? Radius.zero
                        : Radius.circular(borderRadius),
                  ),
                  borderSide: BorderSide(color: Colors.red.shade700),
                ),
                focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(borderRadius),
                    bottom: showPanel
                        ? Radius.zero
                        : Radius.circular(borderRadius),
                  ),
                  borderSide: BorderSide(color: Colors.red.shade700),
                ),
                errorMaxLines: 3,
                errorStyle: TextStyle(
                  color: Colors.red.shade700,
                  fontSize: SizeConfig.blockSizeHorizontal * 2.8,
                  height: 1.25,
                ),
                suffixIcon: _resolvingSelection
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
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
