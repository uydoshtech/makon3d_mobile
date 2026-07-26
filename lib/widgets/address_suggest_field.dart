import "dart:async";

import "package:flutter/material.dart";

import "package:makon3d_mobile/l10n/l10n.dart";
import "package:makon3d_mobile/services/geocode_service.dart";
import "package:makon3d_mobile/theme/makon_colors.dart";

/// A Material address field with Yandex-backed suggestions.
///
/// The API key never reaches the app: requests use the backend's anonymous,
/// IP-rate-limited `/makon3d/geocode/suggest` proxy. Free-form entry stays
/// available if the network or suggestion service is unavailable.
class AddressSuggestField extends StatefulWidget {
  const AddressSuggestField({
    required this.controller,
    required this.suffixIcon,
    super.key,
  });

  final TextEditingController controller;
  final Widget suffixIcon;

  @override
  State<AddressSuggestField> createState() => _AddressSuggestFieldState();
}

class _AddressSuggestFieldState extends State<AddressSuggestField> {
  static const _debounceDuration = Duration(milliseconds: 350);

  final _focusNode = FocusNode();
  final _sessionToken = GeocodeService.newSuggestSessionToken();
  Timer? _debounce;
  List<AddressSuggestion> _suggestions = const [];
  bool _isLoading = false;
  int _requestGeneration = 0;
  bool _selectingSuggestion = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    _focusNode
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _onTextChanged() {
    if (_selectingSuggestion) return;
    _debounce?.cancel();
    final text = widget.controller.text.trim();
    if (text.length < 2) {
      _requestGeneration++;
      if (_suggestions.isNotEmpty || _isLoading) {
        setState(() {
          _suggestions = const [];
          _isLoading = false;
        });
      }
      return;
    }
    _debounce = Timer(_debounceDuration, () => _loadSuggestions(text));
  }

  Future<void> _loadSuggestions(String text) async {
    final generation = ++_requestGeneration;
    if (mounted) setState(() => _isLoading = true);
    final suggestions = await GeocodeService.suggest(
      text: text,
      sessionToken: _sessionToken,
      lang: L10n.currentLanguage,
    );
    if (!mounted || generation != _requestGeneration) return;
    setState(() {
      _suggestions = suggestions;
      _isLoading = false;
    });
  }

  void _select(AddressSuggestion suggestion) {
    _selectingSuggestion = true;
    _debounce?.cancel();
    widget.controller.value = TextEditingValue(
      text: suggestion.address,
      selection: TextSelection.collapsed(offset: suggestion.address.length),
    );
    _selectingSuggestion = false;
    setState(() => _suggestions = const []);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final showSuggestions = _focusNode.hasFocus && _suggestions.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(
            labelText: L10n.get("project_address_label"),
            helperText: L10n.get("project_address_optional_hint"),
            border: const OutlineInputBorder(),
            suffixIcon: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : widget.suffixIcon,
          ),
        ),
        if (showSuggestions)
          Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 5,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, indent: 16, endIndent: 16),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                return ListTile(
                  dense: true,
                  leading: const Icon(
                    Icons.location_on_outlined,
                    color: MakonColors.inkMuted,
                  ),
                  title: Text(suggestion.address),
                  subtitle: suggestion.subtitle?.isNotEmpty == true
                      ? Text(suggestion.subtitle!)
                      : null,
                  onTap: () => _select(suggestion),
                );
              },
            ),
          ),
      ],
    );
  }
}
