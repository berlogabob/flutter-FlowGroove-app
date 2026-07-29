import 'package:flutter/material.dart';

import 'unified_item_model.dart';

/// Trailing actions widget for unified items
class UnifiedItemTrailingActions<T extends UnifiedItemModel>
    extends StatelessWidget {

  const UnifiedItemTrailingActions({
    required this.item,
    super.key,
    this.onEdit,
    this.onDelete,
    this.customActions = const [],
    this.showCompact = false,
    this.additionalActions = const [],
  });
  final T item;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final List<UnifiedItemAction> customActions;
  final bool showCompact;
  final List<UnifiedItemAction> additionalActions;

  @override
  Widget build(BuildContext context) {
    final List<Widget> actions = [];

    // Add custom actions
    actions.addAll(customActions.map((action) => action.build(context)));

    // Add additional actions (e.g., Add to Band)
    actions.addAll(additionalActions.map((action) => action.build(context)));

    // NOTE: Edit and Delete buttons removed - use tap-to-edit and swipe-to-delete instead
    // This follows the unified interaction pattern

    return Row(mainAxisSize: MainAxisSize.min, children: actions);
  }
}
