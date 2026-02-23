import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SortOption {
  manual('Manual'),
  alphabetical('Alphabetical'),
  dateAdded('Date Added'),
  dateModified('Date Modified');

  const SortOption(this.label);
  final String label;
}

class UnifiedFilterSortWidget extends StatelessWidget {
  final SortOption currentSort;
  final ValueChanged<SortOption> onSortChanged;
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
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
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
              controller: TextEditingController(text: filterText),
              onChanged: onFilterChanged,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),

          // Sort dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButton<SortOption>(
              value: currentSort,
              onChanged: onSortChanged,
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
