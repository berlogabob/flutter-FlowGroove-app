# RepSync - Release Process

**Last Updated:** February 19, 2026
**Version:** 1.0.0

---

## Table of Contents

1. [Version Numbering](#version-numbering)
2. [Release Workflow](#release-workflow)
3. [Changelog Guidelines](#changelog-guidelines)
4. [Distribution Channels](#distribution-channels)
5. [Post-Release Tasks](#post-release-tasks)
6. [Emergency Hotfixes](#emergency-hotfixes)

---

## Version Numbering

RepSync follows [Semantic Versioning](https://semver.org/) with Flutter's build number convention.

### Format

```
MAJOR.MINOR.PATCH+BUILD
```

**Example:** `1.0.1+2`

| Component | Description | When to Increment |
|-----------|-------------|-------------------|
| **MAJOR** | Breaking changes | Incompatible API changes, major feature releases |
| **MINOR** | New features | Backward-compatible functionality |
| **PATCH** | Bug fixes | Backward-compatible bug fixes |
| **BUILD** | Build number | Every release to stores (required by Play Store/App Store) |

### Version Examples

| Version | Meaning |
|---------|---------|
| `1.0.0+1` | Initial release |
| `1.0.1+2` | Bug fix release |
| `1.1.0+3` | New features added |
| `2.0.0+4` | Major breaking changes |

### Update Version in pubspec.yaml

```yaml
# pubspec.yaml
name: flutter_repsync_app
description: "RepSync - Band repertoire management"
version: 1.0.1+2  # Update this line

environment:
  sdk: ^3.10.7
```

### Update Platform-Specific Versions

#### Android (`android/app/build.gradle`)

```gradle
android {
    defaultConfig {
        versionCode 2      // Increment for each release
        versionName "1.0.1" // User-visible version
    }
}
```

#### iOS (`ios/Runner/Info.plist`)

```xml
<key>CFBundleShortVersionString</key>
<string>1.0.1</string>
<key>CFBundleVersion</key>
<string>2</string>
```

---

## Release Workflow

### Phase 1: Pre-Release Preparation

#### 1.1 Create Release Branch

```bash
# Create release branch from main
git checkout -b release/v1.0.1

# Push to remote
git push -u origin release/v1.0.1
```

#### 1.2 Update Version Numbers

- [ ] Update `pubspec.yaml` version
- [ ] Update Android version info
- [ ] Update iOS version info
- [ ] Commit changes

```bash
git add pubspec.yaml
git add android/app/build.gradle
git add ios/Runner/Info.plist
git commit -m "Bump version to 1.0.1+2"
```

#### 1.3 Update Changelog

- [ ] Create/update `CHANGELOG.md`
- [ ] Document all changes since last release
- [ ] Include breaking changes, new features, bug fixes

#### 1.4 Run Final Tests

```bash
# Run all tests
flutter test

# Run analysis
flutter analyze

# Build all targets
flutter build web --release
flutter build apk --release
flutter build ios --release
```

#### 1.5 Update Documentation

- [ ] Update `README.md` if needed
- [ ] Update `QUICK_START.md` if needed
- [ ] Update any other relevant docs

---

### Phase 2: Release Build

#### 2.1 Create Release Candidate Tag

```bash
# Create tag
git tag -a v1.0.1-rc.1 -m "Release candidate 1 for v1.0.1"
git push origin v1.0.1-rc.1
```

#### 2.2 Build Release Artifacts

```bash
# Clean previous builds
flutter clean

# Web
flutter build web --release --base-href "/flutter-repsync-app/"

# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

#### 2.3 Test Release Builds

- [ ] Test web build on multiple browsers
- [ ] Test APK on Android devices
- [ ] Test iOS build on devices
- [ ] Verify all features work
- [ ] Check for any runtime errors

---

### Phase 3: Release

#### 3.1 Merge to Main

```bash
# Checkout main
git checkout main

# Merge release branch
git merge release/v1.0.1

# Push to main
git push origin main
```

#### 3.2 Create Release Tag

```bash
# Create final tag
git tag -a v1.0.1 -m "Release v1.0.1"
git push origin v1.0.1
```

#### 3.3 Create GitHub Release

1. Go to GitHub repository
2. Releases → Create new release
3. Tag: `v1.0.1`
4. Title: "RepSync v1.0.1"
5. Description: Copy from CHANGELOG.md
6. Attach binaries (APK, etc.)
7. Publish release

#### 3.4 Deploy to Distribution Channels

**Web (GitHub Pages):**

```bash
make deploy
```

**Web (Firebase Hosting):**

```bash
firebase deploy --only hosting
```

**Android (Play Store):**

1. Upload App Bundle to Google Play Console
2. Fill in release notes
3. Submit for review

**iOS (App Store):**

1. Upload build via Xcode
2. Configure in App Store Connect
3. Submit for review

---

### Phase 4: Post-Release

#### 4.1 Verify Deployment

- [ ] Web app accessible at production URL
- [ ] Play Store listing updated
- [ ] App Store listing updated
- [ ] GitHub release published

#### 4.2 Monitor for Issues

- [ ] Check crash reports (Firebase Crashlytics)
- [ ] Monitor user feedback
- [ ] Watch GitHub issues
- [ ] Check app store reviews

#### 4.3 Announce Release

- [ ] Update project README with latest version
- [ ] Post announcement (if applicable)
- [ ] Notify beta testers
- [ ] Update any public documentation

#### 4.4 Cleanup

```bash
# Delete release branch
git branch -d release/v1.0.1
git push origin --delete release/v1.0.1
```

---

## Changelog Guidelines

### Format

Follow [Keep a Changelog](https://keepachangelog.com/) format.

### Structure

```markdown
# Changelog

All notable changes to RepSync will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.1] - 2026-02-19

### Added
- New features that were added

### Changed
- Changes to existing functionality

### Deprecated
- Features that will be removed in future

### Removed
- Features that were removed

### Fixed
- Bug fixes

### Security
- Security improvements
```

### Example Changelog Entry

```markdown
## [1.0.1] - 2026-02-19

### Added
- Global bands collection for multi-user collaboration
- Spotify API integration for BPM and musical key detection
- 6-character unique invite codes for band joining
- Band member role system (admin/editor/viewer)

### Changed
- Moved bands from user-specific to global Firestore collection
- Updated Firestore security rules for global band access
- Improved error messages for network failures

### Fixed
- Fixed issue where band invite codes could collide
- Fixed BPM not displaying for some Spotify tracks
- Fixed PDF export cutting off long setlist names
- Fixed crash when joining band with invalid code

### Security
- Added Firestore rules for global band collection access control
- Environment variables now properly excluded from version control
```

### Writing Good Changelog Entries

**DO:**

✅ Be specific about what changed
✅ Include issue/PR numbers if applicable
✅ Explain the impact on users
✅ Use clear, concise language

**DON'T:**

❌ Just say "bug fixes" or "improvements"
❌ Include internal refactoring without user impact
❌ Use technical jargon without explanation
❌ Forget to mention breaking changes

---

## Distribution Channels

### Web Deployment

#### GitHub Pages (Primary)

**URL:** `https://berlogabob.github.io/flutter-repsync-app/`

**Deployment:**

```bash
make deploy
```

**Process:**
1. Build with correct base-href
2. Copy to `docs/` folder
3. Commit and push
4. GitHub Pages auto-deploys

#### Firebase Hosting (Secondary)

**URL:** `https://repsync-app-8685c.web.app`

**Deployment:**

```bash
firebase deploy --only hosting
```

**Process:**
1. Build for web
2. Deploy via Firebase CLI
3. Instant global CDN deployment

### Android Distribution

#### Google Play Store (Recommended)

**Process:**
1. Build App Bundle: `flutter build appbundle --release`
2. Upload to Google Play Console
3. Fill in release notes
4. Submit for review
5. Review typically takes 1-3 days

**Pros:**
- Automatic updates for users
- Wide distribution
- Built-in crash reporting

**Cons:**
- $25 one-time developer fee
- Review process required
- 15-30% revenue share (if paid)

#### Direct APK Distribution

**Process:**
1. Build APK: `flutter build apk --release`
2. Host APK on website/GitHub
3. Users download and install manually

**Pros:**
- No review process
- No fees
- Full control

**Cons:**
- Manual updates for users
- Security warnings on install
- Limited distribution

### iOS Distribution

#### Apple App Store (Primary)

**Process:**
1. Build and archive in Xcode
2. Upload to App Store Connect
3. Configure app listing
4. Submit for review
5. Review typically takes 1-3 days

**Pros:**
- Only distribution method for most users
- Automatic updates
- Built-in analytics

**Cons:**
- $99/year developer fee
- Strict review guidelines
- 15-30% revenue share

#### TestFlight (Beta Testing)

**Process:**
1. Upload build to App Store Connect
2. Enable TestFlight
3. Add testers (up to 100 internal, 10000 external)
4. Testers install via TestFlight app

**Use for:**
- Beta testing before release
- Internal team testing
- Limited external testing

### Desktop Distribution

#### Linux

- Direct binary distribution
- Package managers (Snap, Flatpak, AUR)
- Distribution-specific packages (.deb, .rpm)

#### macOS

- Direct download (DMG)
- Mac App Store
- Homebrew tap

#### Windows

- Direct download (ZIP/exe)
- Microsoft Store (MSIX)
- Installer (Inno Setup, NSIS)

---

## Post-Release Tasks

### Immediate (Day 1)

- [ ] Verify all deployment channels are live
- [ ] Test production builds
- [ ] Monitor crash reports
- [ ] Respond to any immediate user issues

### Short-Term (Week 1)

- [ ] Collect user feedback
- [ ] Monitor app store reviews
- [ ] Track adoption metrics
- [ ] Document any known issues

### Long-Term (Ongoing)

- [ ] Plan next release
- [ ] Prioritize bug fixes
- [ ] Gather feature requests
- [ ] Update roadmap

---

## Emergency Hotfixes

### When to Hotfix

- Critical bug affecting core functionality
- Security vulnerability
- App crash on launch
- Data loss issue

### Hotfix Process

#### 1. Create Hotfix Branch

```bash
git checkout -b hotfix/v1.0.2 main
```

#### 2. Fix the Issue

- Make minimal changes to fix the issue
- Test thoroughly
- Document the fix

#### 3. Bump Patch Version

```yaml
# pubspec.yaml
version: 1.0.2+3  # Increment PATCH and BUILD
```

#### 4. Quick Testing

- Test on all platforms
- Focus on the fixed issue
- Verify no regressions

#### 5. Deploy Immediately

```bash
# Merge to main
git checkout main
git merge hotfix/v1.0.2
git push origin main

# Tag release
git tag -a v1.0.2 -m "Hotfix v1.0.2"
git push origin v1.0.2

# Deploy web
make deploy

# Deploy mobile (expedited review)
# Note: "Critical Bug Fix" in review notes
```

#### 6. Post-Hotfix

- Document the issue and fix
- Update CHANGELOG
- Plan follow-up if needed
- Review how issue occurred (prevent recurrence)

---

## Release Checklist Template

### Pre-Release

- [ ] All features tested
- [ ] All bugs fixed or documented
- [ ] Version numbers updated
- [ ] Changelog updated
- [ ] Documentation updated
- [ ] Tests passing
- [ ] Analysis clean

### Release Build

- [ ] Release branch created
- [ ] Release candidate tagged
- [ ] All builds successful
- [ ] Release builds tested

### Release

- [ ] Merged to main
- [ ] Tagged release
- [ ] GitHub release created
- [ ] Web deployed
- [ ] Android submitted
- [ ] iOS submitted

### Post-Release

- [ ] Deployments verified
- [ ] Monitoring active
- [ ] Users notified
- [ ] Branches cleaned up

---

## Resources

- [Semantic Versioning](https://semver.org/)
- [Keep a Changelog](https://keepachangelog.com/)
- [Flutter Release Guide](https://docs.flutter.dev/deployment)
- [Google Play Release Management](https://support.google.com/googleplay/android-developer/answer/9829747)
- [App Store Release Management](https://developer.apple.com/app-store/submissions/)

---

**Release Process Version:** 1.0
**Last Updated:** February 19, 2026
