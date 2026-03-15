# Web Version Display Fix

## Problem
The web build was showing an outdated version number (`0.10.0+1`) instead of the current version (`0.13.0+142`).

### Root Cause
Flutter's web build system caches the `version.json` file and doesn't always pick up changes from `pubspec.yaml`. This is a known issue with Flutter's web build process.

## Solution

### 1. Created Version Fix Script
**File:** `scripts/fix-version.sh`

This script:
- Extracts the current version from `pubspec.yaml`
- Generates a fresh `version.json` with correct version and build number
- Updates both `build/web/version.json` and `docs/version.json`

**Usage:**
```bash
# After building web
flutter build web --release
./scripts/fix-version.sh
```

### 2. Updated Makefile
Modified the `build-web` target to automatically run the version fix script:

```makefile
build-web:
	@echo "🔨 Building web app..."
	@flutter build web --release --base-href "/flutter-FlowGroove-app/"
	@./scripts/fix-version.sh
	@echo "✅ Web build complete: build/web/"
	@ls -lh build/web/ | tail -5
```

### 3. Updated Profile Screen
**File:** `lib/screens/profile_screen.dart`

Changed version display to:
- Always combine version and buildNumber: `version+buildNumber`
- Consistent format across all platforms (Android, iOS, Web)
- Displays as `0.13.0+143`

**Before:**
```dart
_version = packageInfo.version;
_buildDate = packageInfo.buildNumber.isNotEmpty 
    ? '+${packageInfo.buildNumber}' 
    : '';
// Display: _buildDate.isNotEmpty ? '$_version$_buildDate' : _version
```

**After:**
```dart
final version = packageInfo.version;
final buildNumber = packageInfo.buildNumber;

if (buildNumber.isNotEmpty) {
  _version = '$version+$buildNumber';  // "0.13.0+143"
} else {
  _version = version;
}
// Display: _version (always shows version+buildNumber)
```

## Testing

### Verify Version Display
1. Build the web app:
   ```bash
   make build-web
   ```

2. Check version.json:
   ```bash
   cat build/web/version.json
   ```
   Should show:
   ```json
   {
     "version": "0.13.0",
     "buildNumber": "142",
     "buildDate": "2026-03-11T14:31:54Z"
   }
   ```

3. Run the app and navigate to Profile screen
4. Version should display as: `0.13.0+142`

### Android vs Web Parity
Both platforms now show the same version format:
- **Android:** `0.13.0+142` ✓
- **Web:** `0.13.0+142` ✓

## Manual Fix (If Needed)

If the script doesn't work, manually create version.json:

```bash
cd /Users/berloga/Documents/GitHub/flutter_repsync_app

cat > build/web/version.json << 'EOF'
{
  "version": "0.13.0",
  "buildNumber": "142",
  "buildDate": "2026-03-11T00:00:00Z"
}
EOF

cp build/web/version.json docs/version.json
```

## Files Modified

| File | Change |
|------|--------|
| `scripts/fix-version.sh` | ✨ New - Automatically fixes version.json |
| `Makefile` | ✏️ Updated - Calls fix-version.sh after web build |
| `lib/screens/profile_screen.dart` | ✏️ Updated - Improved version display format |
| `build/web/version.json` | ✏️ Fixed - Correct version and build number |
| `docs/version.json` | ✏️ Fixed - Correct version and build number |

## Future Builds

Going forward, the version will be automatically fixed when you run:
- `make build-web`
- `make deploy`
- `make release`

Or manually run the script after `flutter build web`:
```bash
./scripts/fix-version.sh
```

## Related Issues

This fix addresses:
1. ✅ Version mismatch between Android and Web
2. ✅ Build number not showing on Web
3. ✅ Outdated version cached in web build
