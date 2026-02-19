import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/song.dart';
import '../../../models/band.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/custom_button.dart';

/// A dialog for adding a song to a band's song bank.
///
/// This dialog allows users to:
/// - Select which band to add the song to
/// - View a preview of the song
/// - Confirm the addition
class AddToBandDialog extends ConsumerStatefulWidget {
  /// The song to add to a band.
  final Song song;

  /// List of bands the user can add the song to.
  final List<Band> bands;

  const AddToBandDialog({super.key, required this.song, required this.bands});

  /// Show the add to band dialog.
  ///
  /// Returns the selected band ID if the user confirms, or null if cancelled.
  static Future<String?> show(
    BuildContext context, {
    required Song song,
    required List<Band> bands,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => AddToBandDialog(song: song, bands: bands),
    );
  }

  @override
  ConsumerState<AddToBandDialog> createState() => _AddToBandDialogState();
}

class _AddToBandDialogState extends ConsumerState<AddToBandDialog> {
  Band? _selectedBand;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to Band'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Song preview section
            _buildSongPreview(),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            // Band selection section
            _buildBandSelection(),
          ],
        ),
      ),
      actions: [
        CustomButton(
          label: 'Cancel',
          variant: ButtonVariant.text,
          onPressed: () => Navigator.pop(context),
        ),
        CustomButton(
          label: 'Add to Band',
          variant: ButtonVariant.primary,
          onPressed: _selectedBand != null ? _confirm : null,
        ),
      ],
    );
  }

  Widget _buildSongPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.color2.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.color1.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note, color: AppColors.color1, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.song.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.song.artist,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (widget.song.ourKey != null)
                _buildInfoChip(
                  icon: Icons.music_note,
                  label: widget.song.ourKey!,
                ),
              if (widget.song.ourBPM != null)
                _buildInfoChip(
                  icon: Icons.speed,
                  label: '${widget.song.ourBPM} BPM',
                ),
              if (widget.song.tags.isNotEmpty)
                ...widget.song.tags
                    .take(3)
                    .map(
                      (tag) =>
                          _buildInfoChip(icon: Icons.label_outline, label: tag),
                    ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.color3.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.color4),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.color4),
          ),
        ],
      ),
    );
  }

  Widget _buildBandSelection() {
    if (widget.bands.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'You are not a member of any bands yet.\nJoin or create a band to share songs.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select a band:',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: ListView.builder(
            itemCount: widget.bands.length,
            itemBuilder: (context, index) {
              final band = widget.bands[index];
              final isSelected = _selectedBand?.id == band.id;
              return _buildBandTile(band, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBandTile(Band band, bool isSelected) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isSelected ? AppColors.color1 : AppColors.color3,
        child: Icon(
          Icons.groups,
          color: isSelected ? Colors.white : AppColors.color4,
        ),
      ),
      title: Text(
        band.name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? AppColors.color1 : null,
        ),
      ),
      subtitle: Text(
        '${band.members.length} member${band.members.length != 1 ? 's' : ''}',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.color1)
          : null,
      selected: isSelected,
      selectedTileColor: AppColors.color3.withValues(alpha: 0.2),
      onTap: () {
        setState(() {
          _selectedBand = band;
        });
      },
    );
  }

  void _confirm() {
    if (_selectedBand != null) {
      Navigator.pop(context, _selectedBand!.id);
    }
  }
}

/// A form field for selecting a band.
///
/// This is an alternative to the dialog for inline band selection.
class BandSelectorField extends StatelessWidget {
  /// The list of bands to choose from.
  final List<Band> bands;

  /// The currently selected band ID.
  final String? value;

  /// Callback when a band is selected.
  final void Function(String?)? onChanged;

  /// Whether the field is enabled.
  final bool enabled;

  const BandSelectorField({
    super.key,
    required this.bands,
    this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (bands.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No bands available. Join or create a band to share songs.',
          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      );
    }

    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Band',
        prefixIcon: Icon(Icons.groups),
      ),
      items: bands.map((band) {
        return DropdownMenuItem(value: band.id, child: Text(band.name));
      }).toList(),
      onChanged: enabled ? onChanged : null,
      validator: (value) {
        if (value == null && bands.isNotEmpty) {
          return 'Please select a band';
        }
        return null;
      },
    );
  }
}
