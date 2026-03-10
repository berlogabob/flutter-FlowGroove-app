import 'package:flutter/material.dart';
import '../../../../../models/section.dart';
import '../../../../../theme/mono_pulse_theme.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/section_color_manager.dart';
import 'color_picker_dialog.dart';

/// Bottom sheet dialog for selecting or creating a section with 2 tabs:
/// - Parts: Section type matrix
/// - Colors: Color assignment matrix
class SectionPicker extends StatefulWidget {
  final Function(String) onSectionSelected;

  const SectionPicker({super.key, required this.onSectionSelected});

  @override
  State<SectionPicker> createState() => _SectionPickerState();
}

class _SectionPickerState extends State<SectionPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _customController = TextEditingController();
  final _colorManager = SectionColorManager();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(MonoPulseSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Add Section',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 28),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTabBar(context),
            const SizedBox(height: 20),
            SizedBox(
              height: AppDimensions.pickerTabHeight,
              child: TabBarView(
                controller: _tabController,
                children: [_buildPartsTab(context), _buildColorsTab(context)],
              ),
            ),
            const SizedBox(height: 20),
            Divider(
              color: Theme.of(
                context,
              ).colorScheme.outline.withValues(alpha: 0.3),
              thickness: 1.5,
            ),
            const SizedBox(height: 16),
            Text(
              'Or create custom:',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            _buildCustomInputRow(context),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(MonoPulseRadius.large),
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: Theme.of(context).colorScheme.onSurface,
        unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
        indicator: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(MonoPulseRadius.large),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        tabs: const [
          Tab(icon: Icon(Icons.grid_view, size: 24), text: 'Parts'),
          Tab(icon: Icon(Icons.palette, size: 24), text: 'Colors'),
        ],
      ),
    );
  }

  Widget _buildCustomInputRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _customController,
            decoration: const InputDecoration(
              hintText: 'Custom name',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(
                horizontal: MonoPulseSpacing.lg,
                vertical: 12,
              ),
            ),
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                widget.onSectionSelected(value.trim());
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () {
            if (_customController.text.trim().isNotEmpty) {
              widget.onSectionSelected(_customController.text.trim());
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.xxl, vertical: 16),
          ),
          child: const Text('Add', style: TextStyle(fontSize: 15)),
        ),
      ],
    );
  }

  Widget _buildPartsTab(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppDimensions.gridSpacing,
        mainAxisSpacing: AppDimensions.gridSpacing,
      ),
      itemCount: Section.templates.length,
      itemBuilder: (context, index) {
        final template = Section.templates[index];
        return _buildSectionButton(context, template, null);
      },
    );
  }

  Widget _buildColorsTab(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppDimensions.gridSpacing,
        mainAxisSpacing: AppDimensions.gridSpacing,
      ),
      itemCount: Section.templates.length,
      itemBuilder: (context, index) {
        final template = Section.templates[index];
        final color = _colorManager.getColorForName(template);
        return _buildSectionButton(context, template, color);
      },
    );
  }

  Widget _buildSectionButton(
    BuildContext context,
    String template,
    Color? color,
  ) {
    return GestureDetector(
      onTap: () {
        if (color != null) {
          _showColorPicker(context, template, color);
        } else {
          // Just notify parent, don't pop - parent will handle closing
          widget.onSectionSelected(template);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: color ?? Theme.of(context).colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(AppDimensions.cardBorderRadius),
          border: Border.all(
            color: color != null
                ? Colors.white.withValues(alpha: 0.5)
                : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.sm, vertical: 12),
            child: Text(
              template,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color != null
                    ? SectionColorPalette.getContrastingTextColor(color)
                    : Theme.of(context).colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showColorPicker(
    BuildContext context,
    String sectionName,
    Color currentColor,
  ) async {
    final newColor = await showDialog<Color>(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(25),
          child: ColorPickerDialog(
            sectionName: sectionName,
            initialColor: currentColor,
          ),
        ),
      ),
    );

    if (newColor != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Color for "$sectionName" updated'),
          backgroundColor: newColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
