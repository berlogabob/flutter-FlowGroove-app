import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/mono_pulse_theme.dart';
import '../widgets/metronome/time_signature_block.dart';
import '../widgets/metronome/central_tempo_circle.dart';
import '../widgets/metronome/fine_adjustment_buttons.dart';
import '../widgets/metronome/song_library_block.dart';
import '../widgets/metronome/bottom_transport_bar.dart';

/// Metronome Screen - Mono Pulse Design
///
/// Complete redesign per Mono Pulse brandbook:
/// - Clean, premium prototype of musical instrument
/// - Minimum elements, maximum air (60-70% empty space)
/// - Central tempo circle as heart of device
/// - Only: Black background, grey surfaces, orange accent
/// - WCAG AA+ contrast, 48px minimum touch zones
/// - Animations: 120-200ms, smooth, functional only
///
/// Screen Structure (Top to Bottom):
/// 1. AppBar (~56px) - Back arrow, title, three dots
/// 2. Time Signature Block (~80-100px) - Accents + beats with +/- buttons
/// 3. Central Tempo Circle (50-60% screen width) - Rotary dial
/// 4. Fine Adjustment Buttons - +1/-1, +5/-5, +10/-10
/// 5. Song Library Block - Compact pill + expanded panel
/// 6. Bottom Transport Bar (64-80px) - Play/Pause, Previous/Next
class MetronomeScreen extends ConsumerWidget {
  const MetronomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: MonoPulseColors.black,
        appBar: _buildAppBar(context),
        body: SafeArea(child: _buildBody(context, ref)),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: MonoPulseColors.black,
      foregroundColor: MonoPulseColors.textPrimary,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      leading: GestureDetector(
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
      title: Text(
        'Metronome',
        style: MonoPulseTypography.headlineLarge.copyWith(
          color: MonoPulseColors.textHighEmphasis,
          fontWeight: FontWeight.bold,
        ),
      ),
      centerTitle: true,
      actions: [
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _showPresetsMenu(context);
          },
          child: Container(
            margin: const EdgeInsets.all(MonoPulseSpacing.sm),
            padding: const EdgeInsets.all(MonoPulseSpacing.sm),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: MonoPulseColors.borderSubtle, width: 1),
            ),
            child: Icon(
              Icons.more_horiz,
              color: MonoPulseColors.textSecondary,
              size: 24,
            ),
          ),
        ),
        const SizedBox(width: MonoPulseSpacing.sm),
      ],
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      child: Column(
        children: [
          // 1. Air gap after AppBar (64-80px)
          const SizedBox(height: MonoPulseSpacing.massive),

          // 2. Time Signature Block
          const TimeSignatureBlock(),

          // Air gap (48px)
          const SizedBox(height: MonoPulseSpacing.massive),

          // 3. Central Tempo Circle
          const CentralTempoCircle(),

          // Air gap (48-64px)
          const SizedBox(height: MonoPulseSpacing.massive),

          // 4. Fine Adjustment Buttons
          const FineAdjustmentButtons(),

          // Air gap (40px)
          const SizedBox(height: MonoPulseSpacing.huge),

          // 5. Song Library Block
          const SongLibraryBlock(),

          // Air gap (32-48px)
          const SizedBox(height: MonoPulseSpacing.xxxl),

          // Spacer to push transport bar to bottom
          const Spacer(),

          // 6. Bottom Transport Bar
          const BottomTransportBar(),

          // Bottom padding
          const SizedBox(height: MonoPulseSpacing.lg),
        ],
      ),
    );
  }

  void _showPresetsMenu(BuildContext context) {
    final popupMenu = PopupMenuButton<String>(
      color: MonoPulseColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
      ),
      onSelected: (value) {
        // Handle preset selection
        switch (value) {
          case 'save_preset':
            // Save current settings as preset
            break;
          case 'load_preset':
            // Load preset
            break;
          case 'reset':
            // Reset to defaults
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'save_preset',
          child: Row(
            children: [
              Icon(
                Icons.save_outlined,
                color: MonoPulseColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: MonoPulseSpacing.md),
              Text(
                'Save Preset',
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'load_preset',
          child: Row(
            children: [
              Icon(
                Icons.folder_open_outlined,
                color: MonoPulseColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: MonoPulseSpacing.md),
              Text(
                'Load Preset',
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                ),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        PopupMenuItem(
          value: 'reset',
          child: Row(
            children: [
              Icon(
                Icons.refresh,
                color: MonoPulseColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: MonoPulseSpacing.md),
              Text(
                'Reset to Defaults',
                style: MonoPulseTypography.bodyMedium.copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    // Show the popup menu
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 60,
        right: MonoPulseSpacing.xxl,
        child: Material(color: Colors.transparent, child: popupMenu),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto-remove after a delay or when tapped outside
    Future.delayed(const Duration(seconds: 3), () {
      overlayEntry.remove();
    });
  }
}
