import 'package:flutter/material.dart';
import '../../theme/mono_pulse_theme.dart';

/// Sort options for unified lists
enum SortOption {
  manual('Manual'),
  alphabetical('Alphabetical'),
  dateAdded('Date Added'),
  dateModified('Date Modified');

  const SortOption(this.label);
  final String label;
}

/// Filter and sort widget for unified item lists
class UnifiedFilterSortWidget extends StatefulWidget {
  final SortOption currentSort;
  final ValueChanged<SortOption?> onSortChanged;
  final String? filterText;
  final ValueChanged<String?> onFilterChanged;

  const UnifiedFilterSortWidget({
    super.key,
    required this.currentSort,
    required this.onSortChanged,
    this.filterText,
    required this.onFilterChanged,
  });

  @override
  State<UnifiedFilterSortWidget> createState() =>
      _UnifiedFilterSortWidgetState();
}

class _UnifiedFilterSortWidgetState extends State<UnifiedFilterSortWidget> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.filterText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(MonoPulseRadius.small),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          // Filter input
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              controller: _controller,
              onChanged: widget.onFilterChanged,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),

          // Sort dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<SortOption>(
              value: widget.currentSort,
              onChanged: widget.onSortChanged,
              items: SortOption.values.map((option) {
                return DropdownMenuItem<SortOption>(
                  value: option,
                  child: Text(option.label),
                );
              }).toList(),
              underline: Container(),
              icon: const Icon(Icons.sort, size: 20, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}
