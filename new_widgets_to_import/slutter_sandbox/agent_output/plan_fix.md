# Agent Planning Report: Tab Selector & Matrix Layout Fixes

## Issues Identified

### 1. Tab Selector Issues
- **Problem**: Blue selection outline is too small and ugly
- **Problem**: Selection silhouette doesn't match tab size
- **Solution**: Change indicator color to light gray, make it full tab size

### 2. Matrix Layout Issues
- **Problem**: GridView doesn't fit screen, requires scrolling
- **Problem**: Color matrix uses circles, Parts matrix uses buttons - inconsistent
- **Solution**: Calculate proper height, use consistent button/card style for both tabs

### 3. Collapsed Widget Height
- **Problem**: Current height is 100px
- **Solution**: Reduce to 50px

## Plan

### Files to Modify
1. `lib/widgets/section_picker.dart` - Tab selector styling, matrix consistency
2. `lib/song_constructor.dart` - Collapsed height adjustment

### Changes Summary

#### Tab Selector (section_picker.dart)
```dart
// Change indicator from blue to light gray
indicator: BoxDecoration(
  color: Colors.grey[300], // Was: primary color
  borderRadius: BorderRadius.circular(8),
),

// Remove fixed height, calculate based on content
SizedBox(
  height: 280, // Reduced from 320 to fit without scroll
  child: TabBarView(...)
)
```

#### Matrix Consistency
- Both tabs use same GridView configuration
- Both tabs use button-style containers (not circles)
- Same spacing, same font sizes, same layout

#### Collapsed Height (song_constructor.dart)
```dart
Widget _buildCollapsedState() {
  return SizedBox(
    height: 50, // Was: 100
    child: PillView(sections: _sections),
  );
}
```

## Milestones
1. ✅ Analyze current implementation
2. Fix tab selector styling
3. Fix matrix height calculation
4. Make both matrices consistent (button style)
5. Adjust collapsed widget height to 50px
6. Test and verify
