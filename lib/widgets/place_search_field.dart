import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/place_suggestion.dart';
import '../providers/planner_controller.dart';

/// A text field with live Nominatim autocomplete. Debouncing and the request
/// itself live in [placeSearchProvider]; this widget just renders suggestions
/// and reports the chosen [PlaceSuggestion].
class PlaceSearchField extends ConsumerStatefulWidget {
  const PlaceSearchField({
    super.key,
    required this.label,
    required this.icon,
    required this.onSelected,
    this.initial,
  });

  final String label;
  final IconData icon;
  final ValueChanged<PlaceSuggestion> onSelected;
  final PlaceSuggestion? initial;

  @override
  ConsumerState<PlaceSearchField> createState() => _PlaceSearchFieldState();
}

class _PlaceSearchFieldState extends ConsumerState<PlaceSearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial?.shortName);
  String _query = '';
  bool _open = false;

  @override
  void didUpdateWidget(covariant PlaceSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reflect an external change (e.g. the swap button) into the text field.
    if (widget.initial != oldWidget.initial &&
        widget.initial?.shortName != _controller.text) {
      _controller.text = widget.initial?.shortName ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _select(PlaceSuggestion place) {
    widget.onSelected(place);
    _controller.text = place.shortName;
    setState(() {
      _open = false;
      _query = '';
    });
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _query.trim().length >= 3
        ? ref.watch(placeSearchProvider(_query))
        : const AsyncData<List<PlaceSuggestion>>([]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(widget.icon),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _query = '';
                        _open = false;
                      });
                    },
                  ),
          ),
          onChanged: (value) => setState(() {
            _query = value;
            _open = value.trim().length >= 3;
          }),
        ),
        if (_open)
          suggestions.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(8),
              child: Text('Search failed: $e',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
            data: (places) {
              if (places.isEmpty) return const SizedBox.shrink();
              return Card(
                margin: const EdgeInsets.only(top: 4),
                child: Column(
                  children: places
                      .map(
                        (p) => ListTile(
                          dense: true,
                          leading: const Icon(Icons.place_outlined),
                          title: Text(p.shortName),
                          subtitle: Text(
                            p.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _select(p),
                        ),
                      )
                      .toList(),
                ),
              );
            },
          ),
      ],
    );
  }
}
