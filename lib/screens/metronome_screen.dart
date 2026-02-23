import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/mono_pulse_theme.dart';
import '../widgets/metronome/time_signature_block.dart';
import '../widgets/metronome/central_tempo_circle.dart';
import '../widgets/metronome/fine_adjustment_buttons.dart';
import '../widgets/metronome/song_library_block.dart';
import '../widgets/metronome/bottom_transport_bar.dart';
import '../widgets/metronome/menu_popup.dart';

/// Metronome Screen - Mono Pulse Design (Sprint Fix)
///
/// Complete redesign per Mono Pulse brandbook:
/// - Clean, premium prototype of musical instrument
/// - Minimum elements, maximum air (60-70% empty space)
/// - Central tempo circle as heart of device
/// - Only: Black background, grey surfaces, orange accent
/// - WCAG AA+ contrast, 48px minimum touch zones
/// - Animations: 120-200ms, smooth, functional only
///
/// Sprint Fixes:
/// - Disable screen scroll (NeverScrollableScrollPhysics on Scaffold)
/// - Three dots menu with Save New Song / Update Song items
///
/// Screen Structure (Top to Bottom):
/// 1. AppBar (~56px) - Back arrow, title, three dots
/// 2. Time Signature Block (~80-100px) - Accents + beats with +/- buttons
/// 3. Central Tempo Circle (50-60% screen width) - Rotary dial
/// 4. Fine Adjustment Buttons - +1/-1, +5/-5, +10/-10
/// 5. Song Library Block - Compact pill + expanded panel
/// 6. Bottom Transport Bar (64-80px) - Play/Pause, Previous/Next
class MetronomeScreen extends ConsumerStatefulWidget {
  const MetronomeScreen({super.key});

  @override
  ConsumerState<MetronomeScreen> createState() => _MetronomeScreenState();
}

class _MetronomeScreenState extends ConsumerState<MetronomeScreen> {
  bool _isMenuOpen = false;
  Offset _menuPosition = Offset.zero;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MonoPulseColors.black,
        // Disable screen scroll per sprint brief
        extendBodyBehindAppBar: false,
        body: SafeArea(
          child: Stack(
            children: [
              // Main content with disabled scroll
              _buildBody(context),
              // Menu popup overlay
              if (_isMenuOpen)
                MenuPopup(
                  position: _menuPosition,
                  onClose: () {
                    setState(() => _isMenuOpen = false);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    // Use NeverScrollableScrollPhysics to disable scroll per sprint brief
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        children: [
          // 1. AppBar
          _buildAppBar(context),

          // 2. Air gap after AppBar (64-80px)
          const SizedBox(height: MonoPulseSpacing.massive),

          // 3. Time Signature Block
          const TimeSignatureBlock(),

          // Air gap (48px)
          const SizedBox(height: MonoPulseSpacing.massive),

          // 4. Central Tempo Circle
          const CentralTempoCircle(),

          // Air gap (48-64px)
          const SizedBox(height: MonoPulseSpacing.massive),

          // 5. Fine Adjustment Buttons
          const FineAdjustmentButtons(),

          // Air gap (40px)
          const SizedBox(height: MonoPulseSpacing.huge),

          // 6. Song Library Block
          const SongLibraryBlock(),

          // Air gap (32-48px)
          const SizedBox(height: MonoPulseSpacing.xxxl),

          // Spacer to push transport bar to bottom
          const Spacer(),

          // 7. Bottom Transport Bar
          const BottomTransportBar(),

          // Bottom padding
          const SizedBox(height: MonoPulseSpacing.lg),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.lg),
      height: 56,
      child: Row(
        children: [
          // Back arrow
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.of(context).pop();
            },
            child: Container(
              margin: const EdgeInsets.all(MonoPulseSpacing.sm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: MonoPulseColors.textSecondary,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.arrow_back_ios_new,
                color: MonoPulseColors.textSecondary,
                size: 18,
              ),
            ),
          ),

          // Title
          Expanded(
            child: Center(
              child: Text(
                'Metronome',
                style: MonoPulseTypography.headlineLarge.copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Three dots menu
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _toggleMenu();
            },
            child: Container(
              margin: const EdgeInsets.all(MonoPulseSpacing.sm),
              padding: const EdgeInsets.all(MonoPulseSpacing.sm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isMenuOpen
                      ? MonoPulseColors.accentOrange
                      : MonoPulseColors.borderSubtle,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.more_vert, // Three vertical dots ⋮
                color: _isMenuOpen
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.textSecondary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: MonoPulseSpacing.sm),
        ],
      ),
    );
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
      if (_isMenuOpen) {
        // Calculate menu position (top-right, below app bar)
        final appBarHeight = 56.0;
        _menuPosition = Offset(
          MonoPulseSpacing.xxl,
          appBarHeight + MonoPulseSpacing.md,
        );
      }
    });
  }
}
