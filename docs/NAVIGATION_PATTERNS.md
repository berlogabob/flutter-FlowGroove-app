# Navigation Patterns

This document outlines the standard navigation and interaction patterns used throughout the RepSync Flutter application. Following these patterns ensures consistency across all screens and provides a predictable user experience.

---

## Table of Contents

1. [Back Button Pattern](#1-back-button-pattern)
2. [FAB Pattern](#2-fab-pattern)
3. [Menu Pattern](#3-menu-pattern)
4. [List Interaction Pattern](#4-list-interaction-pattern)
5. [Form Submission Pattern](#5-form-submission-pattern)
6. [Loading State Pattern](#6-loading-state-pattern)
7. [Error State Pattern](#7-error-state-pattern)
8. [Navigation Methods](#8-navigation-methods)
9. [Standard Error Handling](#9-standard-error-handling)
10. [Success Feedback Patterns](#10-success-feedback-patterns)
11. [Confirmation Dialog Usage](#11-confirmation-dialog-usage)

---

## 1. Back Button Pattern

The back button visibility depends on the screen type and navigation context.

### Main Tab Screens (No Back Button)

Main tab screens are root-level screens in the navigation stack. They should **not** display a back button.

```dart
StandardScreenScaffold(
  title: 'Songs',
  showBackButton: false,
  body: ...,
)
```

**When to use `showBackButton: false`:**
- Home screen
- Songs list screen
- Bands list screen
- Community screen
- Profile screen
- Any screen that is a primary tab destination

### Detail/Edit Screens (With Back Button)

Detail, edit, and form screens are child screens. They **should** display a back button (this is the default behavior).

```dart
StandardScreenScaffold(
  title: 'Add Song',
  showBackButton: true, // default - can be omitted
  body: ...,
)
```

**When to use `showBackButton: true` (or omit):**
- Song detail view
- Band detail view
- Add/Edit forms
- Settings sub-screens
- Any screen navigated to from another screen

---

## 2. FAB Pattern

Floating Action Buttons (FABs) provide primary actions on screens. Choose the appropriate FAB variant based on the number of actions.

### Single Action - Use `SingleFab`

When there is only one primary action:

```dart
floatingActionButton: SingleFab(
  icon: Icons.add,
  onPressed: _createItem,
  heroTag: 'items_fab',
)
```

**Properties:**
- `icon`: The icon to display (typically `Icons.add` for create actions)
- `onPressed`: Callback function for the action
- `heroTag`: Unique tag for hero animations (use descriptive names like `'songs_fab'`, `'bands_fab'`)

### Dual Actions - Use `DualFab`

When there are two related primary actions:

```dart
floatingActionButton: DualFab(
  primary: FabAction(
    icon: Icons.add,
    label: 'Create',
    onPressed: _create,
  ),
  secondary: FabAction(
    icon: Icons.group_add,
    label: 'Join',
    onPressed: _join,
  ),
)
```

**Properties:**
- `primary`: The main action (displayed prominently)
- `secondary`: The secondary action (displayed when FAB is expanded)
- `FabAction.icon`: Icon for the action
- `FabAction.label`: Text label shown on expansion
- `FabAction.onPressed`: Callback function

**Common Dual FAB Patterns:**
- Create / Join (for bands)
- Add / Import (for songs)
- New / Template (for forms)

---

## 3. Menu Pattern

Screen-level actions that don't warrant a FAB should be placed in the overflow menu.

### Basic Menu Items

```dart
StandardScreenScaffold(
  // ... other properties
  menuItems: [
    PopupMenuItem<void>(
      child: const Text('Save'),
      onTap: _save,
    ),
    PopupMenuItem<void>(
      child: const Text('Import'),
      onTap: _import,
    ),
  ],
)
```

### Menu Item with Icon

```dart
PopupMenuItem<void>(
  value: 'delete',
  child: Row(
    children: [
      Icon(Icons.delete, color: Colors.red),
      SizedBox(width: 8),
      Text('Delete'),
    ],
  ),
  onTap: _delete,
)
```

### Divider Between Menu Sections

```dart
menuItems: [
  PopupMenuItem<void>(child: const Text('Save'), onTap: _save),
  const PopupMenuDivider(),
  PopupMenuItem<void>(child: const Text('Export'), onTap: _export),
  PopupMenuItem<void>(child: const Text('Delete'), onTap: _delete),
],
```

**When to use menu items:**
- Save actions (for forms)
- Import/Export functionality
- Settings and configuration
- Destructive actions (delete, remove)
- Secondary actions that don't need prominent display

---

## 4. List Interaction Pattern

The `UnifiedItemList` widget provides a consistent list experience with built-in support for common interactions.

### Basic List

```dart
UnifiedItemList<T>(
  items: items,
  onTap: _handleTap,
  onEdit: _handleEdit,
  onDelete: _handleDelete,
)
```

### List with Reordering

```dart
UnifiedItemList<T>(
  items: items,
  enableReorder: sortOption == SortOption.manual,
  onReorder: _handleReorder,
  onTap: _handleTap,
)
```

### List with Custom Actions

```dart
UnifiedItemList<T>(
  items: items,
  onTap: _handleTap,
  additionalActionsBuilder: (index) => [
    _CustomAction(
      icon: Icons.share,
      onPressed: () => _share(items[index]),
    ),
  ],
)
```

### Full Featured List

```dart
UnifiedItemList<T>(
  items: items,
  enableReorder: sortOption == SortOption.manual,
  onReorder: _handleReorder,
  onDelete: _handleDelete, // Shows ConfirmationDialog automatically
  onTap: _handleTap,
  onEdit: _handleEdit,
  additionalActionsBuilder: (index) => [
    _CustomAction(onPressed: _doSomething),
  ],
)
```

**Properties:**
- `items`: List of items to display
- `enableReorder`: Enable drag-to-reorder (typically for manual sort)
- `onReorder`: Callback when item order changes
- `onDelete`: Callback for delete (triggers confirmation dialog)
- `onTap`: Callback for item tap (navigate to detail)
- `onEdit`: Callback for edit action
- `additionalActionsBuilder`: Function returning custom action buttons per item

---

## 5. Form Submission Pattern

Consistent form behavior improves user experience and reduces confusion.

### Text Field Navigation Actions

```dart
// Intermediate fields - move to next field
TextFormField(
  textInputAction: TextInputAction.next,
)

// Final field - triggers save
TextFormField(
  textInputAction: TextInputAction.done,
  onFieldSubmitted: (_) => _save(),
)
```

### Save Action in Menu

For forms, the save action should be accessible from the menu:

```dart
StandardScreenScaffold(
  // ... other properties
  menuItems: [
    PopupMenuItem<void>(
      onTap: _save,
      child: const Text('Save'),
    ),
  ],
)
```

### Success Feedback

After successful form submission, show a SnackBar:

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(content: Text('Saved successfully!')),
);
```

### Complete Form Pattern

```dart
class AddSongScreen extends StatelessWidget {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _artistController = TextEditingController();

  void _save() {
    if (_formKey.currentState!.validate()) {
      // Save logic here
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Song saved successfully!')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StandardScreenScaffold(
      title: 'Add Song',
      menuItems: [
        PopupMenuItem<void>(onTap: _save, child: const Text('Save')),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Song Name'),
              textInputAction: TextInputAction.next,
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
            TextFormField(
              controller: _artistController,
              decoration: const InputDecoration(labelText: 'Artist'),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              validator: (value) => value?.isEmpty ?? true ? 'Required' : null,
            ),
          ],
        ),
      ),
      floatingActionButton: SingleFab(
        icon: Icons.save,
        onPressed: _save,
        heroTag: 'add_song_fab',
      ),
    );
  }
}
```

---

## 6. Loading State Pattern

Use consistent loading indicators throughout the application.

### LoadingIndicator Widget

```dart
LoadingIndicator(
  size: 40,
  message: 'Loading...',
)
```

### AsyncValue Loading State

When using Riverpod's `AsyncValue`:

```dart
asyncValue.when(
  loading: () => const Center(
    child: LoadingIndicator(),
  ),
  error: (error, stack) => ErrorBanner.card(
    message: 'Failed to load data',
    onRetry: _refresh,
  ),
  data: (data) => ContentWidget(data: data),
)
```

### Full Screen Loading

```dart
if (isLoading) {
  return const Center(
    child: LoadingIndicator(
      size: 50,
      message: 'Please wait...',
    ),
  );
}
```

### Inline Loading

```dart
Row(
  children: [
    Text('Syncing...'),
    SizedBox(width: 8),
    LoadingIndicator(size: 20),
  ],
)
```

**Properties:**
- `size`: Diameter of the spinner in pixels (default: 40)
- `message`: Optional text displayed below the spinner

---

## 7. Error State Pattern

Different error scenarios require different error display strategies.

### Full-Screen Error (No Data)

Use when the entire screen cannot display content due to an error:

```dart
ErrorBanner.card(
  message: 'Failed to load data',
  onRetry: _refresh,
)
```

**When to use:**
- Initial data load fails
- No cached data available
- Critical dependency unavailable

### Form Error Banner (Top of Screen)

Use for form-level validation or submission errors:

```dart
ErrorBanner.banner(
  message: 'Validation error',
  onRetry: _retry,
)
```

**When to use:**
- Form validation errors
- Submission failures
- Network errors during form operations

### Inline Error (With Cached Data)

Use when displaying cached data but background operations fail:

```dart
ErrorBanner.inline(
  message: 'Sync failed',
  onRetry: _sync,
)
```

**When to use:**
- Data sync failures (cached data still shown)
- Non-critical background operation failures
- Partial data availability

### Empty States

Use empty state widgets when there is no data to display:

```dart
// For songs
EmptyState.songs(onAdd: _addSong)

// For search results
EmptyState.search(query: _searchQuery)

// For bands
EmptyState.bands(onCreate: _createBand, onJoin: _joinBand)
```

**Empty State Types:**
- `EmptyState.songs`: No songs in list
- `EmptyState.bands`: No bands joined/created
- `EmptyState.search`: No results for search query
- `EmptyState.community`: No community content
- `EmptyState.custom`: Custom empty state with icon, title, subtitle, and action

---

## 8. Navigation Methods

Understanding when to use different navigation methods is crucial for proper app behavior.

### `pushNamed` - Add to Navigation Stack

Use `pushNamed` when you want to:
- Navigate to a new screen and expect to return
- Create a new entry in the navigation history
- Allow the user to press back to return

```dart
Navigator.of(context).pushNamed(
  '/song-detail',
  arguments: songId,
);

// User can press back to return
```

**Common use cases:**
- Navigating to detail screens
- Opening forms (Add/Edit)
- Viewing settings sub-screens
- Any temporary navigation

### `goNamed` - Replace Current Route

Use `goNamed` (from go_router or similar) when you want to:
- Replace the current screen entirely
- Not allow the user to return via back button
- Reset the navigation stack

```dart
Navigator.of(context).pushReplacementNamed(
  '/login',
);

// Or with go_router:
context.goNamed('login');

// User cannot press back to return
```

**Common use cases:**
- Login/Logout flows
- Onboarding completion
- Authentication redirects
- Major state changes

### `pop` - Return to Previous Screen

```dart
// Simple pop
Navigator.pop(context);

// Pop with result
Navigator.pop(context, result);

// Pop multiple screens
Navigator.popUntil(context, ModalRoute.withName('/home'));
```

### Navigation Best Practices

1. **Main tabs should not have back buttons** - They are root screens
2. **Use meaningful hero tags** - For smooth transitions between related screens
3. **Pass minimal data in arguments** - Pass IDs, fetch full data on destination
4. **Handle navigation in callbacks** - Keep navigation logic separate from business logic
5. **Consider deep linking** - Structure route names for potential deep link support

---

## 9. Standard Error Handling

Consistent error handling improves debugging and user experience.

### Try-Catch Pattern

```dart
try {
  await someAsyncOperation();
} catch (e, stackTrace) {
  // Log the error
  logger.e('Operation failed', error: e, stackTrace: stackTrace);
  
  // Show user-friendly error
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Failed to complete operation: ${e.toString()}'),
      backgroundColor: Colors.red,
    ),
  );
}
```

### AsyncValue Error Handling

```dart
final asyncValue = someProvider.watch();

asyncValue.when(
  loading: () => const LoadingIndicator(),
  error: (error, stack) {
    logger.e('Load failed', error: error, stackTrace: stack);
    return ErrorBanner.card(
      message: _getErrorMessage(error),
      onRetry: () => ref.invalidate(someProvider),
    );
  },
  data: (data) => ContentWidget(data: data),
)
```

### Error Message Mapping

```dart
String _getErrorMessage(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have permission to perform this action';
      case 'unavailable':
        return 'Service temporarily unavailable. Please try again.';
      default:
        return 'An error occurred. Please try again.';
    }
  }
  if (error is SocketException) {
    return 'No internet connection. Please check your network.';
  }
  return 'An unexpected error occurred.';
}
```

---

## 10. Success Feedback Patterns

Provide clear feedback for successful operations.

### SnackBar for Simple Actions

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text('Song saved successfully!'),
    duration: const Duration(seconds: 2),
    behavior: SnackBarBehavior.floating,
  ),
);
```

### SnackBar with Action

```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: const Text('Song deleted'),
    action: SnackBarAction(
      label: 'Undo',
      onPressed: _undoDelete,
    ),
  ),
);
```

### Success Dialog for Important Actions

```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Success!'),
    content: const Text('Your band has been created.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('OK'),
      ),
    ],
  ),
);
```

### Inline Success Message

```dart
if (showSuccessMessage) {
  Container(
    padding: const EdgeInsets.all(12),
    color: Colors.green.shade50,
    child: Row(
      children: [
        Icon(Icons.check_circle, color: Colors.green),
        SizedBox(width: 8),
        Text('Changes saved successfully!', style: TextStyle(color: Colors.green.shade800)),
      ],
    ),
  );
}
```

---

## 11. Confirmation Dialog Usage

Always confirm destructive actions before execution.

### Basic Confirmation Dialog

```dart
final confirmed = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text('Delete Song'),
    content: const Text('Are you sure you want to delete this song? This action cannot be undone.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        style: TextButton.styleFrom(foregroundColor: Colors.red),
        child: const Text('Delete'),
      ),
    ],
  ),
);

if (confirmed == true) {
  await _deleteSong();
}
```

### Using ConfirmationDialog Widget

```dart
final confirmed = await ConfirmationDialog.show(
  context: context,
  title: 'Delete Band',
  message: 'Are you sure you want to leave this band?',
  confirmLabel: 'Leave',
  confirmColor: Colors.red,
);

if (confirmed) {
  await _leaveBand();
}
```

### UnifiedItemList Delete Confirmation

The `UnifiedItemList` widget automatically shows a confirmation dialog when `onDelete` is provided:

```dart
UnifiedItemList(
  items: items,
  onDelete: (item) async {
    // This will be called only after user confirms
    await _deleteItem(item);
  },
)
```

### Confirmation Dialog Best Practices

1. **Clear title** - State what action is being confirmed
2. **Descriptive message** - Explain consequences of the action
3. **Action-oriented buttons** - Use specific labels like "Delete" not "Yes"
4. **Destructive color** - Use red for destructive actions
5. **Cancel is safe** - Cancel should always be the default/safe option

---

## Quick Reference

| Pattern | Widget/Method | When to Use |
|---------|---------------|-------------|
| Back Button | `showBackButton: false` | Main tab screens |
| Back Button | `showBackButton: true` | Detail/Edit screens |
| Single Action FAB | `SingleFab` | One primary action |
| Dual Action FAB | `DualFab` | Two related actions |
| Menu Items | `PopupMenuItem` | Secondary actions, Save |
| List | `UnifiedItemList` | All item lists |
| Loading | `LoadingIndicator` | All async operations |
| Error (full) | `ErrorBanner.card` | No data available |
| Error (inline) | `ErrorBanner.inline` | Cached data with sync error |
| Empty | `EmptyState.*` | No items to display |
| Navigate forward | `pushNamed` | Temporary navigation |
| Navigate replace | `goNamed` | Authentication, major state change |
| Success | `SnackBar` | Operation completed |
| Confirm | `AlertDialog` | Destructive actions |

---

## Related Documentation

- [Existing Tools & Widgets](./EXISTING_TOOLS_WIDGETS.md)
- [Tools Architecture](./TOOLS_ARCHITECTURE.md)
- [Screen Unification Report](../SCREEN_UNIFICATION_REPORT.md)
