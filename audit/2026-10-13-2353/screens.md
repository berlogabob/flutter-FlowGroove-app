# Screen inventory — FlowGroove 0.25.0+363 (debug build, commit 40480801)
Device: Huawei ELE-L29 (P30), Android 10, 1080x2340. Date 2026-10-13/14. Account: read-only Demo (safe to crawl).
Tooling: Maestro cannot drive EMUI; crawl is pure adb (screencap + uiautomator dump, Flutter semantics active).
Screens: screens/android/<name>.png, hierarchy/<name>.json (names below).
login: cold start (first frame after install is a blank white screen ~10s, debug build) | home: Try Demo Account
tab_songs / tab_bands / tab_setlists: bottom nav | menu: bottom nav Menu | settings (+settings_scrolled): Menu > Settings
setlist_detail: Setlists > Saturday Night Set | song_detail: Songs > Billie Jean | song_sheet, song_lab: song tabs
quick_add_song: Home > Quick Action Song (Add Song form, not saved) | band_create: Bands > Create band
band_detail: Bands > The Cover Collective | band_songs, band_rehearsals: band quick actions
tool_tuner, tool_metronome, tool_rehearsals (band picker), tool_recorder, tool_practice: Home > Tools
NOT COVERED: real-account data, write flows (demo is read-only), Sign Up screen, Quick Actions Band/Setlist/Audio note,
event sharing / personal events (0.25.0 headline feature), concert mode, performance sheet with content, offline/error states,
web, iOS, tablet. Login with email/Google not exercised.
