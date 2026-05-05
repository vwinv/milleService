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
  Timer? _debounce;
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _hideOverlay();
      _debounce?.cancel();
      setState(() => _predictions = []);
    }
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _predictions = []);
      _hideOverlay();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _fetchSuggestions(value.trim());
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    if (query.length < 2) return;
    setState(() => _loading = true);
    _showOverlay();

    final list = await _geocoding.autocomplete(query);

    if (mounted) {
      setState(() {
        _predictions = list;
        _loading = false;
      });
      _updateOverlay();
    }
  }

  void _showOverlay() {
    _hideOverlay();
    _overlayEntry = OverlayEntry(builder: (context) => _buildOverlayContent());
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  Widget _buildOverlayContent() {
    return Positioned(
      // Nécessaire pour respecter les contraintes de Positioned dans l'Overlay.
      left: 0,
      top: 0,
      width: widget.width,
      child: CompositedTransformFollower(
        link: _layerLink,
        showWhenUnlinked: false,
        offset: Offset(0, widget.height < 48 ? 48.0 : widget.height),
        child: Material(
          elevation: 4,
          color: Colors.white,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(SizeConfig.blockSizeHorizontal * 10),
            bottomRight: Radius.circular(SizeConfig.blockSizeHorizontal * 10),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: _loading && _predictions.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(SizeConfig.blockSizeHorizontal * 3),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : (_predictions.isEmpty
                      ? Padding(
                          padding: EdgeInsets.all(
                            SizeConfig.blockSizeHorizontal * 3,
                          ),
                          child: const Text(
                            'Aucune adresse trouvée',
                            style: TextStyle(color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: _predictions.length,
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
                        )),
          ),
        ),
      ),
    );
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onSelectSuggestion(AutocompleteSuggestion suggestion) {
    _hideOverlay();
    setState(() => _predictions = []);
    widget.controller.text = suggestion.displayName;
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _debounce?.cancel();
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = widget.height < 48 ? 48.0 : widget.height;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: SizeConfig.blockSizeHorizontal * 5,
        vertical: SizeConfig.blockSizeVertical * 1,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: widget.label.isNotEmpty ? SizeConfig.blockSizeVertical * 1 : 0,
        children: [
          widget.label.isNotEmpty
              ? Text(widget.label, style: widget.labelStyle)
              : SizedBox.shrink(),
          CompositedTransformTarget(
            link: _layerLink,
            child: Container(
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
                borderRadius: BorderRadius.all(
                  Radius.circular(SizeConfig.blockSizeHorizontal * 10),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
