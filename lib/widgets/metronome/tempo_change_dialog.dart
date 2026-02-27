import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/mono_pulse_theme.dart';

/// Tempo Change Dialog - Modal for changing tempo via Tap or Keyboard
///
/// Features:
/// - Title "Change tempo" 24px Bold #EDEDED
/// - Two buttons: "Tap" (#FF5E00, finger icon), "Keyboard" (#111111, keyboard icon)
/// - Toggle "Apply instantly" (orange switch)
/// - Keyboard input field #121212, border #FF5E00 on focus
/// - Buttons Cancel / Apply: left #A0A0A5, right #FF5E00
class TempoChangeDialog extends StatefulWidget {
  final int bpm;

  const TempoChangeDialog({super.key, required this.bpm});

  @override
  State<TempoChangeDialog> createState() => _TempoChangeDialogState();
}

class _TempoChangeDialogState extends State<TempoChangeDialog> {
  bool _useKeyboard = false;
  bool _applyInstantly = true;
  final _textController = TextEditingController();
  bool _isValid = true;

  @override
  void initState() {
    super.initState();
    _textController.text = widget.bpm.toString();
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: MonoPulseColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MonoPulseRadius.xlarge),
      ),
      child: Padding(
        padding: const EdgeInsets.all(MonoPulseSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              'Change tempo',
              style: MonoPulseTypography.headlineLarge.copyWith(
                color: MonoPulseColors.textHighEmphasis,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: MonoPulseSpacing.xxl),

            // Mode selection buttons
            Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    label: 'Tap',
                    icon: Icons.touch_app_outlined,
                    isSelected: !_useKeyboard,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _useKeyboard = false);
                    },
                  ),
                ),
                const SizedBox(width: MonoPulseSpacing.md),
                Expanded(
                  child: _ModeButton(
                    label: 'Keyboard',
                    icon: Icons.keyboard_outlined,
                    isSelected: _useKeyboard,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _useKeyboard = true);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: MonoPulseSpacing.xl),

            // Keyboard input (shown only when keyboard mode selected)
            if (_useKeyboard) ...[
              TextField(
                controller: _textController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: MonoPulseTypography.headlineMedium.copyWith(
                  color: MonoPulseColors.textHighEmphasis,
                ),
                decoration: InputDecoration(
                  hintText: 'Values from 1 to 600',
                  hintStyle: MonoPulseTypography.bodyMedium.copyWith(
                    color: MonoPulseColors.textTertiary,
                  ),
                  filled: true,
                  fillColor: MonoPulseColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(MonoPulseRadius.large),
                    borderSide: BorderSide(
                      color: _isValid
                          ? MonoPulseColors.borderDefault
                          : MonoPulseColors.error,
                      width: 2,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(MonoPulseRadius.large),
                    borderSide: const BorderSide(
                      color: MonoPulseColors.accentOrange,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: MonoPulseSpacing.lg,
                    horizontal: MonoPulseSpacing.xl,
                  ),
                ),
                onChanged: (value) {
                  final bpm = int.tryParse(value);
                  setState(() {
                    _isValid = bpm != null && bpm >= 1 && bpm <= 300;
                  });
                },
              ),
              if (!_isValid) ...[
                const SizedBox(height: MonoPulseSpacing.sm),
                Text(
                  'Please enter a value between 1 and 600',
                  style: MonoPulseTypography.labelSmall.copyWith(
                    color: MonoPulseColors.error,
                  ),
                ),
              ],
              const SizedBox(height: MonoPulseSpacing.lg),
            ],

            // Tap mode info
            if (!_useKeyboard) ...[
              Container(
                padding: const EdgeInsets.all(MonoPulseSpacing.lg),
                decoration: BoxDecoration(
                  color: MonoPulseColors.blackSurface,
                  borderRadius: BorderRadius.circular(MonoPulseRadius.large),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: MonoPulseColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: MonoPulseSpacing.md),
                    Expanded(
                      child: Text(
                        'Tap the rhythm you want to set. We\'ll calculate the BPM for you.',
                        style: MonoPulseTypography.bodyMedium.copyWith(
                          color: MonoPulseColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MonoPulseSpacing.lg),
            ],

            // Apply instantly toggle
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Apply instantly',
                  style: MonoPulseTypography.bodyMedium.copyWith(
                    color: MonoPulseColors.textSecondary,
                  ),
                ),
                _OrangeSwitch(
                  value: _applyInstantly,
                  onChanged: (value) => setState(() => _applyInstantly = value),
                ),
              ],
            ),
            const SizedBox(height: MonoPulseSpacing.xl),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Cancel',
                    isPrimary: false,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: MonoPulseSpacing.md),
                Expanded(
                  child: _ActionButton(
                    label: 'Apply',
                    isPrimary: true,
                    isEnabled: _isValid,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      final bpm = _useKeyboard
                          ? int.tryParse(_textController.text) ?? widget.bpm
                          : widget.bpm;
                      Navigator.of(
                        context,
                      ).pop({'bpm': bpm, 'applyInstantly': _applyInstantly});
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<_ModeButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isPressed = _isPressed;
    final isSelected = widget.isSelected;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: isPressed ? 0.95 : 1.0,
        duration: MonoPulseAnimation.durationShort,
        curve: MonoPulseAnimation.curveCustom,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.lg),
          decoration: BoxDecoration(
            color: isSelected
                ? MonoPulseColors.accentOrange.withValues(alpha: 0.15)
                : MonoPulseColors.blackElevated,
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
            border: Border.all(
              color: isSelected
                  ? MonoPulseColors.accentOrange
                  : MonoPulseColors.borderSubtle,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.icon,
                color: isSelected
                    ? MonoPulseColors.accentOrange
                    : MonoPulseColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: MonoPulseSpacing.sm),
              Text(
                widget.label,
                style: MonoPulseTypography.labelLarge.copyWith(
                  color: isSelected
                      ? MonoPulseColors.accentOrange
                      : MonoPulseColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrangeSwitch extends StatelessWidget {
  final bool value;
  final Function(bool) onChanged;

  const _OrangeSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: MonoPulseColors.accentOrange,
      activeTrackColor: MonoPulseColors.accentOrange.withValues(alpha: 0.5),
      inactiveThumbColor: MonoPulseColors.textTertiary,
      inactiveTrackColor: MonoPulseColors.borderDefault,
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final bool isPrimary;
  final bool isEnabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.isPrimary,
    this.isEnabled = true,
    required this.onTap,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isPressed = _isPressed;
    final isEnabled = widget.isEnabled;

    return GestureDetector(
      onTapDown: (_) {
        if (isEnabled) setState(() => _isPressed = true);
      },
      onTapUp: (_) {
        if (isEnabled) {
          setState(() => _isPressed = false);
          widget.onTap();
        }
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: isPressed ? 0.95 : 1.0,
        duration: MonoPulseAnimation.durationShort,
        curve: MonoPulseAnimation.curveCustom,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: MonoPulseSpacing.lg),
          decoration: BoxDecoration(
            color: widget.isPrimary
                ? (isEnabled
                      ? MonoPulseColors.accentOrange
                      : MonoPulseColors.borderDefault)
                : MonoPulseColors.blackElevated,
            borderRadius: BorderRadius.circular(MonoPulseRadius.large),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: MonoPulseTypography.labelLarge.copyWith(
                color: widget.isPrimary
                    ? (isEnabled
                          ? MonoPulseColors.black
                          : MonoPulseColors.textDisabled)
                    : (isEnabled
                          ? MonoPulseColors.textSecondary
                          : MonoPulseColors.textDisabled),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
