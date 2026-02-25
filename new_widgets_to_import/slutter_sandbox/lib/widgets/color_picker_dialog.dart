import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Color picker dialog with 3 methods: theme colors, color wheel, hex input
class ColorPickerDialog extends StatefulWidget {
  final String sectionName;
  final Color initialColor;

  const ColorPickerDialog({
    super.key,
    required this.sectionName,
    required this.initialColor,
  });

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Color _selectedColor;
  final _hexController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _selectedColor = widget.initialColor;
    _hexController.text = AppColorPalette.colorToHex(widget.initialColor);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _hexController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 16),
          _buildTabBar(context),
          const SizedBox(height: 16),
          SizedBox(
            height: AppDimensions.colorPickerHeight,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildThemeTab(context),
                _buildWheelTab(context),
                _buildHexTab(context),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Pick Color for "${widget.sectionName}"',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _selectedColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.black26, width: 2),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return TabBar(
      controller: _tabController,
      labelColor: Theme.of(context).colorScheme.primary,
      unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
      tabs: const [
        Tab(text: 'Theme'),
        Tab(text: 'Wheel'),
        Tab(text: 'Hex'),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context, _selectedColor);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedColor,
            foregroundColor: AppColorPalette.getContrastingTextColor(_selectedColor),
          ),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _buildThemeTab(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildThemeColorsGrid(context),
          const SizedBox(height: 16),
          _buildSuggestedColorsGrid(context),
        ],
      ),
    );
  }

  Widget _buildThemeColorsGrid(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final color in AppColorPalette.themeColors)
          _buildColorCircle(context, color),
      ],
    );
  }

  Widget _buildSuggestedColorsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Suggested for ${widget.sectionName}:',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final color in AppColorPalette.getSuggestedColors(widget.sectionName))
              _buildColorCircle(context, color),
          ],
        ),
      ],
    );
  }

  Widget _buildColorCircle(BuildContext context, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedColor = color;
          _hexController.text = AppColorPalette.colorToHex(color);
        });
      },
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _selectedColor == color
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 3,
          ),
        ),
        child: _selectedColor == color
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Widget _buildWheelTab(BuildContext context) {
    return Column(
      children: [
        _buildHueSlider(context),
        const SizedBox(height: 8),
        _buildSaturationSlider(context),
        const SizedBox(height: 8),
        _buildBrightnessSlider(context),
        const SizedBox(height: 16),
        _buildPaletteGrid(context),
      ],
    );
  }

  Widget _buildHueSlider(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 24,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
      ),
      child: Slider(
        value: HSVColor.fromColor(_selectedColor).hue / 360,
        onChanged: (value) {
          setState(() {
            _selectedColor = HSVColor.fromAHSV(1.0, value * 360, 1.0, 1.0).toColor();
            _hexController.text = AppColorPalette.colorToHex(_selectedColor);
          });
        },
      ),
    );
  }

  Widget _buildSaturationSlider(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 16,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),
      child: Slider(
        value: HSVColor.fromColor(_selectedColor).saturation,
        onChanged: (value) {
          setState(() {
            final hsv = HSVColor.fromColor(_selectedColor);
            _selectedColor = HSVColor.fromAHSV(1.0, hsv.hue, value, hsv.value).toColor();
            _hexController.text = AppColorPalette.colorToHex(_selectedColor);
          });
        },
      ),
    );
  }

  Widget _buildBrightnessSlider(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 16,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
      ),
      child: Slider(
        value: HSVColor.fromColor(_selectedColor).value,
        onChanged: (value) {
          setState(() {
            final hsv = HSVColor.fromColor(_selectedColor);
            _selectedColor = HSVColor.fromAHSV(1.0, hsv.hue, hsv.saturation, value).toColor();
            _hexController.text = AppColorPalette.colorToHex(_selectedColor);
          });
        },
      ),
    );
  }

  Widget _buildPaletteGrid(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (int i = 0; i < AppColorPalette.paletteColors.length; i++)
          GestureDetector(
            onTap: () {
              setState(() {
                _selectedColor = AppColorPalette.paletteColors[i];
                _hexController.text = AppColorPalette.colorToHex(_selectedColor);
              });
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColorPalette.paletteColors[i],
                shape: BoxShape.circle,
                border: Border.all(
                  color: _selectedColor == AppColorPalette.paletteColors[i]
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHexTab(BuildContext context) {
    return Column(
      children: [
        _buildHexInput(context),
        const SizedBox(height: 16),
        _buildHexPresets(context),
      ],
    );
  }

  Widget _buildHexInput(BuildContext context) {
    return TextField(
      controller: _hexController,
      decoration: InputDecoration(
        labelText: 'Hex Color Code',
        hintText: '#RRGGBB',
        prefixText: '#',
        border: const OutlineInputBorder(),
        helperText: 'Enter 6-digit hex code (e.g., FF5733)',
      ),
      maxLength: 6,
      textCapitalization: TextCapitalization.characters,
      onChanged: (value) {
        if (value.length == 6) {
          final color = AppColorPalette.hexToColor(value);
          if (color != null) {
            setState(() {
              _selectedColor = color;
            });
          }
        }
      },
    );
  }

  Widget _buildHexPresets(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AppColorPalette.hexPresets.entries.map((entry) {
        return _HexPresetChip(
          color: Color(entry.value),
          hex: entry.key,
          onTap: (hex, color) {
            setState(() {
              _selectedColor = color;
              _hexController.text = hex;
            });
          },
        );
      }).toList(),
    );
  }
}

class _HexPresetChip extends StatelessWidget {
  final Color color;
  final String hex;
  final Function(String, Color) onTap;

  const _HexPresetChip({
    required this.color,
    required this.hex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(hex, color),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black26),
        ),
        child: Text(
          hex,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
          ),
        ),
      ),
    );
  }
}
