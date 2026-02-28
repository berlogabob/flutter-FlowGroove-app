import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/tools/tool_scaffold.dart';
import '../../widgets/tools/tool_transport_bar.dart';

/// Template for new tool screens.
///
/// This template provides a standardized structure for all tool screens:
/// - ToolScreenScaffold for consistent layout
/// - Provider-based state management
/// - Responsive design support
/// - Haptic feedback integration
///
/// Usage:
/// 1. Copy this file to `lib/screens/tools/[tool_name]_screen.dart`
/// 2. Replace [ToolName] with your tool name
/// 3. Implement provider and state
/// 4. Customize mainWidget, secondaryWidget, bottomWidget
///
/// Example:
/// ```dart
/// class RecorderScreen extends ConsumerStatefulWidget {
///   const RecorderScreen({super.key});
///
///   @override
///   ConsumerState<RecorderScreen> createState() => _RecorderScreenState();
/// }
/// ```
class NewToolScreen extends ConsumerStatefulWidget {
  const NewToolScreen({super.key});

  @override
  ConsumerState<NewToolScreen> createState() => _NewToolScreenState();
}

class _NewToolScreenState extends ConsumerState<NewToolScreen> {
  // Tool-specific state variables
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return ToolScreenScaffold(
      title: 'New Tool',
      menuItems: _buildMenuItems(),
      mainWidget: _buildMainContent(),
      secondaryWidget: _buildSecondaryControls(),
      bottomWidget: _buildTransportBar(),
      showOfflineIndicator: true,
    );
  }

  /// Build menu items for 3-dot menu.
  ///
  /// Common menu items:
  /// - Save Preset
  /// - Load Preset
  /// - Reset to Defaults
  /// - Settings
  List<PopupMenuItem<dynamic>> _buildMenuItems() {
    return [
      PopupMenuItem<dynamic>(
        child: const Text('Save Preset'),
        onTap: _savePreset,
      ),
      PopupMenuItem<dynamic>(
        child: const Text('Load Preset'),
        onTap: _loadPreset,
      ),
      const PopupMenuDivider(),
      PopupMenuItem<dynamic>(
        child: const Text('Reset to Defaults'),
        onTap: _resetToDefaults,
      ),
    ];
  }

  /// Build main content widget.
  ///
  /// This is the primary control area of the tool.
  /// Examples:
  /// - Metronome: CentralTempoCircle
  /// - Tuner: CentralDial
  /// - Recorder: RecordingVisualizer
  Widget _buildMainContent() {
    return Center(
      child: Text(
        'Main Control Area',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
    );
  }

  /// Build secondary controls widget (optional).
  ///
  /// This widget appears between main content and transport bar.
  /// Examples:
  /// - Metronome: FineAdjustmentButtons
  /// - Tuner: (none)
  /// - Recorder: RecordingSettings
  Widget? _buildSecondaryControls() {
    return null;
  }

  /// Build transport bar widget (optional).
  ///
  /// This widget provides transport controls (play, stop, etc.).
  /// Examples:
  /// - Metronome: BottomTransportBar
  /// - Tuner: TransportBar
  /// - Recorder: RecordingControls
  Widget? _buildTransportBar() {
    return ToolTransportBar(
      isPlaying: _isPlaying,
      onPlayPause: _togglePlay,
      showNavigation: false,
      showSettings: false,
    );
  }

  // Tool-specific methods

  void _togglePlay() {
    setState(() => _isPlaying = !_isPlaying);
    // Add haptic feedback
    HapticFeedback.mediumImpact();
  }

  void _savePreset() {
    // Implement preset saving logic
    debugPrint('Save preset');
  }

  void _loadPreset() {
    // Implement preset loading logic
    debugPrint('Load preset');
  }

  void _resetToDefaults() {
    // Implement reset logic
    debugPrint('Reset to defaults');
  }
}

// Example Provider (uncomment and customize)
/*
enum ToolState {
  idle,
  active,
}

class ToolNotifier extends StateNotifier<ToolState> {
  ToolNotifier() : super(ToolState.idle);

  void start() {
    state = ToolState.active;
  }

  void stop() {
    state = ToolState.idle;
  }

  void toggle() {
    state = state == ToolState.active ? ToolState.idle : ToolState.active;
  }

  @override
  void dispose() {
    // Clean up resources
    super.dispose();
  }
}

final toolProvider = StateNotifierProvider<ToolNotifier, ToolState>(
  (ref) => ToolNotifier(),
);
*/
