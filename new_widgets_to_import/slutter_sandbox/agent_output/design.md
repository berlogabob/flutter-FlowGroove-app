# UI Design Specification: Song Structure Constructor (Updated)

## Layouts

### Main Widget Layout
- **Container** with `AspectRatio(aspectRatio: 2/1)` or fixed height (~200-250px)
- **Card** wrapper with elevation: 2, margin: 16, borderRadius: 12

### Collapsed State Layout
```
┌─────────────────────────────────────────────┐
│ Song Structure              [expand_less]   │  <- Header Row
├─────────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐    │  <- Pill Container
│  │ [Intro][Verse][Chorus][Outro]       │    │  <- Colored blocks
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
```
- **Header**: Row with Text("Song Structure") + IconButton(expand_less)
- **Pill**: Horizontal Row in Container with rounded borders (borderRadius: 20)
- **Blocks**: Fixed height (~40px), width proportional to duration

### Expanded State Layout
```
┌─────────────────────────────────────────────┐
│ Song Structure  [Auto-Generate] [expand_more]│ <- Header Row
├─────────────────────────────────────────────┤
│ ┌─────────────────────────────────────────┐ │
│ │ Intro                          [delete] │ │ <- Card 1
│ │ Duration: 2 phrases                      │ │
│ │ Notes: Guitar intro in Am               │ │
│ └─────────────────────────────────────────┘ │
│ ┌─────────────────────────────────────────┐ │
│ │ Verse                          [delete] │ │ <- Card 2
│ │ Duration: 4 phrases                      │ │
│ │ Notes: Am - C - G - D                   │ │
│ └─────────────────────────────────────────┘ │
│           [+ Add Section]                    │
└─────────────────────────────────────────────┘
```
- **Header**: Row with Text + Auto-Generate Button + IconButton(expand_more)
- **List**: Vertical ReorderableListView of SectionCard
- **Add Button**: Centered ElevatedButton.icon at bottom

### EditSectionDialog Layout (Bottom Sheet)
```
┌─────────────────────────────────────────────┐
│ Edit Section                                │
├─────────────────────────────────────────────┤
│ Section Type:                               │
│ [Dropdown: Intro ▼]                         │
│                                             │
│ Duration (phrases):                         │
│ [1] [2] [3] [4]  [Custom: __]               │
│                                             │
│ Notes:                                      │
│ ┌─────────────────────────────────────────┐ │
│ │ Guitar chords: Am C G                   │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│          [Cancel]          [Save]           │
└─────────────────────────────────────────────┘
```

## User Flow

```
1. App starts → Collapsed state
   └─> If empty: Show "No structure yet" placeholder in pill

2. User taps expand icon → Expanded state
   └─> Shows vertical list of sections

3. User taps "Add Section" → SectionPicker opens
   └─> Select template or custom → Section added to list

4. User taps section card → EditSectionDialog opens
   └─> Modify name, duration (with helper buttons), notes
   └─> Save → Updates list, rebuilds pill

5. User long-presses section → Drag to reorder
   └─> Release → Section reordered

6. User taps delete icon → Confirm dialog
   └─> Confirm → Section removed

7. User taps collapse icon → Collapsed state
   └─> Pill shows colored blocks proportional to duration
```

## Components

### PillView (Collapsed State Visualization)
- **Type**: StatelessWidget
- **Container**: 
  - height: 40-50px
  - decoration: BoxDecoration with borderRadius: 20 (pill shape)
  - color: primaryContainer
- **Children**: Row of block containers
  - Each block: Fixed height, width = (duration / totalDuration) * availableWidth
  - Color: Hash-based from section name (`Colors.primaries[section.name.hashCode % Colors.primaries.length]`)
  - No text labels (pure visual)

### SectionCard (Expanded State Item)
- **Type**: StatelessWidget in Dismissible or with trailing delete button
- **Card**: elevation: 1, margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8)
- **Content**:
  - ListTile or Padding with Column
  - Row: Text(name, bold, title) + Spacer + IconButton(delete)
  - Text("Duration: X phrases", subtitle, small)
  - Text(notes, bodySmall, italic if not empty)
- **Interactions**: onTap → edit

### DurationHelper (Part of EditSectionDialog)
- **Type**: StatelessWidget or inline Row
- **Children**: 
  - Row of ElevatedButtons: "1", "2", "3", "4"
  - TextField (optional, for custom values)
- **Behavior**: Tap button → sets duration value

## Color Scheme
- **Pill blocks**: `Colors.primaries[section.name.hashCode % Colors.primaries.length]`
- **Intro**: Blues
- **Verse**: Greens
- **Chorus**: Reds/Oranges
- **Bridge**: Purples
- **Outro**: Teals

## Accessibility
- Semantics on pill blocks: "Intro, 2 phrases"
- Minimum tap targets: 48x48
- High contrast text
