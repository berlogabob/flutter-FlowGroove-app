import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/analytics_consent_provider.dart';
import '../../providers/haptics_provider.dart';
import '../../providers/keep_screen_on_provider.dart';
import '../../providers/theme_mode_provider.dart';
import '../../theme/mono_pulse_theme.dart';
import '../../utils/app_version.dart';
import '../../widgets/bottom_nav_or_action_bar.dart';
import '../../widgets/support_sheet.dart';
import '../../widgets/unified_item/song_card_actions.dart';
import 'api_access_screen.dart';

/// Global app settings (#129) — the single home for app-wide preferences,
/// reachable from the main-menu 3-dots on every tab. Profile keeps only
/// account things.
class AppSettingsScreen extends ConsumerStatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  ConsumerState<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends ConsumerState<AppSettingsScreen> {
  static const _latencyKey = 'metronome_latency_offset_ms';
  int _latencyMs = 0;
  String _version = 'Loading...';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) {
        setState(() => _latencyMs = prefs.getInt(_latencyKey) ?? 0);
      }
    });
    loadAppVersionString().then((v) {
      if (mounted) setState(() => _version = v);
    });
  }

  Future<void> _setLatency(int ms) async {
    final clamped = ms.clamp(-200, 500);
    setState(() => _latencyMs = clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_latencyKey, clamped);
  }

  @override
  Widget build(BuildContext context) {
    final keepScreenOn = ref.watch(keepScreenOnProvider);
    final haptics = ref.watch(hapticsEnabledProvider);
    final analyticsConsent = ref.watch(analyticsConsentProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Root-navigator pushed route: the shell's bottom bar isn't underneath,
    // so this screen renders its own pushed-mode bar — otherwise there is no
    // way back on web (beta feedback on 0.16.0).
    return Scaffold(
      backgroundColor: context.mp.black,
      bottomNavigationBar: AppBottomBar.actions(
        onBack: () => context.pop(),
        title: 'Settings',
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(MonoPulseSpacing.lg),
          children: [
            _section(context, 'General', [
              SwitchListTile(
                secondary: const Icon(
                  Icons.lightbulb_outline,
                  color: MonoPulseColors.accentOrange,
                ),
                title: const Text('Keep screen on'),
                subtitle: const Text('Never dim while FlowGroove is open'),
                value: keepScreenOn,
                onChanged: (_) =>
                    ref.read(keepScreenOnProvider.notifier).toggle(),
              ),
              SwitchListTile(
                secondary: const Icon(
                  Icons.vibration,
                  color: MonoPulseColors.accentOrange,
                ),
                title: const Text('Haptics'),
                subtitle: const Text('Vibration feedback, incl. metronome'),
                value: haptics,
                onChanged: (_) =>
                    ref.read(hapticsEnabledProvider.notifier).toggle(),
              ),
              ListTile(
                leading: const Icon(
                  Icons.dark_mode_outlined,
                  color: MonoPulseColors.accentOrange,
                ),
                title: const Text('Theme'),
                // In `trailing` the 3-segment control squeezed this title
                // down to a near-zero-width column ("Theme" wrapped one
                // letter per line). `subtitle` gives both the label and the
                // control their own full-width row.
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: MonoPulseSpacing.sm),
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (s) =>
                        ref.read(themeModeProvider.notifier).set(s.first),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: MonoPulseSpacing.lg),
            _section(context, 'Songs', [
              ListTile(
                leading: const Icon(
                  Icons.push_pin_outlined,
                  color: MonoPulseColors.accentOrange,
                ),
                title: const Text('Quick action on song cards'),
                subtitle: const Text('What the pinned card button does'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showQuickActionPicker(context, ref),
              ),
            ]),
            const SizedBox(height: MonoPulseSpacing.lg),
            _section(context, 'Privacy', [
              SwitchListTile(
                secondary: const Icon(
                  Icons.analytics_outlined,
                  color: MonoPulseColors.accentOrange,
                ),
                title: const Text('Share usage analytics'),
                subtitle: const Text('Helps us see which features get used'),
                value: analyticsConsent,
                onChanged: (_) =>
                    ref.read(analyticsConsentProvider.notifier).toggle(),
              ),
            ]),
            const SizedBox(height: MonoPulseSpacing.lg),
            _section(context, 'AI', [
              ListTile(
                leading: const Icon(
                  Icons.smart_toy_outlined,
                  color: MonoPulseColors.accentOrange,
                ),
                title: const Text('AI access (MCP)'),
                subtitle: const Text('Connect your own AI to read & add songs'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ApiAccessScreen(),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: MonoPulseSpacing.lg),
            _section(context, 'Advanced', [
              ListTile(
                leading: const Icon(
                  Icons.timer_outlined,
                  color: MonoPulseColors.accentOrange,
                ),
                title: const Text('Audio latency offset'),
                subtitle: const Text(
                  'Shift the metronome click if your audio route lags',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove),
                      onPressed: () => _setLatency(_latencyMs - 10),
                    ),
                    Text('$_latencyMs ms'),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _setLatency(_latencyMs + 10),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: MonoPulseSpacing.lg),
            _section(context, 'Support', [
              ListTile(
                leading: const Icon(
                  Icons.headset_mic_outlined,
                  color: MonoPulseColors.accentOrange,
                ),
                title: const Text('Contact support'),
                subtitle: const Text('Reach us on Telegram or WhatsApp'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showSupportSheet(context, appVersion: _version),
              ),
            ]),
            const SizedBox(height: MonoPulseSpacing.lg),
            _section(context, 'About', [
              ListTile(
                title: const Text('Version'),
                trailing: Text(
                  _version,
                  style: TextStyle(color: context.mp.textSecondary),
                ),
              ),
            ]),
            const SizedBox(height: MonoPulseSpacing.lg),
            const _MadeByFooter(),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: MonoPulseSpacing.sm,
            bottom: MonoPulseSpacing.sm,
          ),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Card(child: Column(children: children)),
      ],
    );
  }
}

/// "Made by berloga with ❤️ from 🇵🇹" as one line — "berloga" links out,
/// heart/flag are emoji only (no duplicated words alongside them).
class _MadeByFooter extends StatelessWidget {
  const _MadeByFooter();

  static final Uri _berlogaUrl = Uri.parse('https://t.me/berloga');

  @override
  Widget build(BuildContext context) {
    final secondary = TextStyle(color: context.mp.textTertiary, fontSize: 12);

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Made by ', style: secondary),
          GestureDetector(
            onTap: () =>
                launchUrl(_berlogaUrl, mode: LaunchMode.externalApplication),
            child: Text(
              'berloga',
              style: secondary.copyWith(
                color: MonoPulseColors.accentOrange,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          Text(' with ❤️ from 🇵🇹', style: secondary),
        ],
      ),
    );
  }
}
