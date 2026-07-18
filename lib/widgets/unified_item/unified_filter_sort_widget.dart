import 'package:flutter/material.dart';
import '../../theme/mono_pulse_theme.dart';

/// Sort options for unified lists
enum SortOption {
  manual('Manual order'),
  alphabetical('Alphabetical'),
  dateAdded('Date Added'),
  dateModified('Date Modified');

  const SortOption(this.label);
  final String label;
}

/// Filter and sort widget for unified item lists
class UnifiedFilterSortWidget extends StatefulWidget {
  const UnifiedFilterSortWidget({
    required this.currentSort,
    required this.onSortChanged,
    required this.onFilterChanged,
    super.key,
    this.filterText,
    this.hintText = 'Search...',
  });

  final SortOption currentSort;
  final ValueChanged<SortOption?> onSortChanged;
  final String? filterText;
  final ValueChanged<String?> onFilterChanged;
  final String hintText;

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
    return DecoratedBox(
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
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: MonoPulseSpacing.lg,
                  vertical: MonoPulseSpacing.sm,
                ),
              ),
              controller: _controller,
              onChanged: widget.onFilterChanged,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),

          // Sort dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.sm),
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
              icon: Icon(Icons.sort, size: 20, color: context.mp.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
