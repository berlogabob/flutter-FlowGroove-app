# CSV Import/Export Guide for RepSync

## Overview

RepSync now supports importing and exporting songs via CSV files, making it easy to migrate from Google Sheets or Excel spreadsheets.

## Quick Start

### Importing Songs

1. **Open RepSync** and go to the Songs screen
2. **Tap the Import button** (upload icon) in the top right corner
3. **Choose import method:**
   - **Select CSV File**: Browse and select a CSV file from your device
   - **Paste from Clipboard**: Copy data from Google Sheets/Excel and paste directly

### Exporting Songs

1. **Open RepSync** and go to the Songs screen
2. **Tap the Export button** (download icon) in the top right corner
3. **Choose export method:**
   - **Save to Device**: Save CSV file to your device
   - **Share**: Share CSV file via email, cloud storage, or other apps

## CSV Format

### Required Columns

- `title` - Song title (required)
- `artist` - Artist name (required)

### Optional Columns

#### Basic Information
- `originalKey` - Original key (e.g., "C", "G#m", "Bb")
- `originalBPM` - Original BPM (integer, 40-300)
- `ourKey` - Your band's key
- `ourBPM` - Your band's BPM
- `spotifyUrl` - Spotify track URL
- `notes` - Song notes
- `bandId` - Band identifier
- `tags` - Comma-separated tags (e.g., "rock,live,cover")
- `accentBeats` - Beats per measure (default: 4)
- `regularBeats` - Subdivisions per beat (default: 1)

#### Sections (up to 10)
Sections are defined using numbered columns:
- `section_1_name`, `section_1_notes`, `section_1_duration`, `section_1_color`
- `section_2_name`, `section_2_notes`, `section_2_duration`, `section_2_color`
- ... up to `section_10_*`

Example section names: "Intro", "Verse", "Chorus", "Bridge", "Outro"

#### Links (up to 5)
- `link_1_url`, `link_1_title`, `link_1_type`
- `link_2_url`, `link_2_title`, `link_2_type`
- ... up to `link_5_*`

Link types: "youtube_original", "youtube_cover", "spotify", "tabs", "drums", "chords", "other"

#### Beat Modes (up to 8×4 grid)
- `beatMode_0_0`, `beatMode_0_1`, `beatMode_0_2`, `beatMode_0_3`
- `beatMode_1_0`, `beatMode_1_1`, ...
- ... up to `beatMode_7_3`

Beat mode values: "accent", "normal", "silent", "rest"

## Google Sheets Migration

### Step-by-Step Migration

1. **Prepare your Google Sheet:**
   - Ensure your data has clear column headers
   - Use the column names from the CSV Format section above
   - Remove any merged cells or complex formatting

2. **Copy your data:**
   - Select all cells with data (including headers)
   - Press `Ctrl+C` (Windows) or `Cmd+C` (Mac)

3. **Import to RepSync:**
   - Open RepSync app
   - Go to Songs screen
   - Tap Import button (upload icon)
   - Select "Paste from Clipboard"
   - Review the preview
   - Tap "Import X Songs"

### Example Google Sheets Layout

| title | artist | originalKey | originalBPM | ourKey | ourBPM | tags | section_1_name | section_1_duration | section_2_name | section_2_duration |
|-------|--------|-------------|-------------|--------|--------|------|----------------|-------------------|----------------|-------------------|
| Bohemian Rhapsody | Queen | Bb | 124 | C | 124 | rock,classic | Intro | 4 | Verse | 8 |
| Sweet Child O' Mine | Guns N' Roses | Eb | 125 | Eb | 125 | rock,live | Intro | 4 | Verse | 8 |

## Tips & Best Practices

### For Best Results

1. **Use consistent headers** - Match the column names exactly as shown in the CSV Format section
2. **Validate before importing** - Review the preview table to ensure data looks correct
3. **Start small** - Test with 2-3 songs first to verify your format
4. **Backup your data** - Export your RepSync songs regularly

### Common Issues

**Issue: "Missing required header: title"**
- Solution: Ensure your CSV has a column named exactly `title` (lowercase)

**Issue: "Invalid integer value for originalBPM"**
- Solution: Check that BPM columns contain only numbers (no text or symbols)

**Issue: "Invalid color format for section"**
- Solution: Use ARGB hex format (e.g., "FF42A5F5") or leave empty for default colors

**Issue: Songs imported but sections missing**
- Solution: Ensure section columns use the format `section_1_name`, `section_1_duration`, etc.

### Advanced Usage

#### Multiple Sections Example

| title | artist | section_1_name | section_1_duration | section_2_name | section_2_duration | section_3_name | section_3_duration |
|-------|--------|----------------|-------------------|----------------|-------------------|----------------|-------------------|
| Song Name | Artist | Intro | 4 | Verse | 8 | Chorus | 8 |

#### Custom Beat Modes

| title | artist | accentBeats | regularBeats | beatMode_0_0 | beatMode_0_1 | beatMode_1_0 | beatMode_1_1 |
|-------|--------|-------------|--------------|--------------|--------------|--------------|--------------|
| Song | Artist | 4 | 2 | accent | normal | normal | normal |

## Troubleshooting

### Import Fails Silently

- Check that your file is saved as CSV (not XLSX or other format)
- Ensure the file uses UTF-8 encoding
- Verify that headers are in the first row

### Data Appears Corrupted

- Check for commas within data fields (use quotes to escape)
- Verify date formats are consistent
- Ensure no extra blank rows at the bottom

### Performance Issues with Large Files

- Import in batches of 50-100 songs
- Remove unnecessary columns
- Simplify section structures if possible

## Support

If you encounter issues not covered in this guide:
1. Export your current songs as a backup
2. Take a screenshot of the error message
3. Share a sample of your CSV file (first few rows)
4. Contact support for assistance

## Export Template

To get started quickly, you can export a template from RepSync:
1. Create one song with all desired fields
2. Export it as CSV
3. Use the exported file as a template for bulk data entry
4. Fill in your data while preserving the header row
