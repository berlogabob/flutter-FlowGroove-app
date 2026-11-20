import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/audio_region.dart';
import '../../services/audio/audio_note_edit.dart';
import '../../theme/mono_pulse_theme.dart';

/// Section occurrences act as banks; pad indices always refer to the song.
class PadBanks extends StatefulWidget {
  const PadBanks({
    required this.regions,
    required this.colorForName,
    required this.onSelect,
    required this.onEdit,
    required this.onRenameSection,
    this.sectionColors = const {},
    this.grid,
    this.selection,
    this.editing = false,
    this.playing = false,
    this.sync = false,
    this.positionMs = 0,
    super.key,
  });

  final List<AudioRegion> regions;
  final AudioGrid? grid;
  final Map<String, Color> sectionColors;
  final Color? Function(String) colorForName;
  final ValueChanged<(int, int)?> onSelect;
  final ValueChanged<int> onEdit;
  final ValueChanged<String> onRenameSection;
  final (int, int)? selection;
  final bool editing;
  final bool playing;
  final bool sync;
  final int positionMs;

  @override
  State<PadBanks> createState() => _PadBanksState();
}

class _PadBanksState extends State<PadBanks> {
  String? _bankId;
  int? _heldPad;
  final _padPointers = <int>{};
  bool _runMade = false;
  int? _heldBank;
  final _bankPointers = <int>{};
  bool _bankRunMade = false;

  String _base(String name) => name.trim().replaceFirst(RegExp(r' \d+$'), '');
  String _time(int ms) => formatTimestamp(ms, padMinutes: false);
  String _bars(AudioGrid grid, AudioRegion region) {
    final bars =
        ((grid.barAt(region.endMs) - grid.barAt(region.startMs)) * 4).round() /
        4;
    return bars == bars.roundToDouble()
        ? bars.toInt().toString()
        : bars.toString();
  }

  @override
  void didUpdateWidget(PadBanks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editing != widget.editing) {
      _heldPad = null;
      _heldBank = null;
      _padPointers.clear();
      _bankPointers.clear();
      _runMade = false;
      _bankRunMade = false;
    }
  }

  void _releasePad(int pointer, int pad) {
    _padPointers.remove(pointer);
    if (_heldPad == pad) _heldPad = null;
    if (_padPointers.isEmpty && _runMade) {
      scheduleMicrotask(() => _runMade = false);
    }
  }

  void _releaseBank(int pointer, int bank) {
    _bankPointers.remove(pointer);
    if (_heldBank == bank) _heldBank = null;
    if (_bankPointers.isEmpty && _bankRunMade) {
      scheduleMicrotask(() => _bankRunMade = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final grid = widget.grid;
    final allVisible = [
      for (final (i, region) in widget.regions.indexed)
        if (editing || !region.skip) i,
    ];
    final banked = allVisible.any((i) => widget.regions[i].section != null);
    final baseColors = <String, Color>{};
    if (banked) {
      for (final region in widget.regions) {
        final color = widget.sectionColors[region.sectionId];
        if (region.section != null && color != null) {
          baseColors.putIfAbsent(
            _base(region.section!).toLowerCase(),
            () => color,
          );
        }
      }
    }
    Color regionColor(AudioRegion region) {
      final name = banked ? _base(region.section ?? region.name) : region.name;
      return (banked
              ? baseColors[name.toLowerCase()]
              : widget.sectionColors[region.sectionId]) ??
          widget.colorForName(name) ??
          context.mp.blackSurface;
    }

    final banks = <(int, int)>[];
    if (banked) {
      for (var i = 0; i < widget.regions.length; i++) {
        final start = i;
        final section = widget.regions[i].section;
        // Group before filtering: a hidden region must not merge occurrences.
        while (section != null &&
            i + 1 < widget.regions.length &&
            widget.regions[i + 1].section == section) {
          i++;
        }
        if (allVisible.any((index) => index >= start && index <= i)) {
          banks.add((start, i));
        }
      }
    }
    var active = banks.indexWhere((b) => widget.regions[b.$1].id == _bankId);
    if (widget.playing && widget.selection == null) {
      final following = banks.indexWhere(
        (b) =>
            widget.positionMs >= widget.regions[b.$1].startMs &&
            widget.positionMs < widget.regions[b.$2].endMs,
      );
      if (following >= 0) active = following;
    }
    if (banks.isNotEmpty) {
      if (active < 0) active = 0;
      _bankId = widget.regions[banks[active].$1].id;
    }
    final visible = !banked
        ? allVisible
        : [
            for (final i in allVisible)
              if (i >= banks[active].$1 && i <= banks[active].$2) i,
          ];
    final pads = GridView.builder(
      padding: const EdgeInsets.all(MonoPulseSpacing.lg),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: banked ? 160 : 120,
        mainAxisExtent: banked ? 88 : 56,
        crossAxisSpacing: MonoPulseSpacing.sm,
        mainAxisSpacing: MonoPulseSpacing.sm,
      ),
      itemCount: visible.length,
      itemBuilder: (context, slot) {
        final i = visible[slot];
        final region = widget.regions[i];
        final selection = widget.selection;
        final selected =
            selection != null && i >= selection.$1 && i <= selection.$2;
        final color = selected
            ? MonoPulseColors.accentOrange
            : region.skip
            ? context.mp.black
            : regionColor(region);
        final foreground =
            ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? MonoPulseColors.white
            : MonoPulseColors.black;
        final playingHere =
            widget.playing &&
            !widget.sync &&
            widget.positionMs >= region.startMs &&
            widget.positionMs < region.endMs;
        return Semantics(
          button: true,
          selected: selected,
          // Runs, MPC style: hold one pad and tap another. Tracked on raw
          // pointers (no long-press delay, no gesture arena) so the scrolling
          // grid can't steal the hold.
          child: Listener(
            onPointerDown: (event) {
              _padPointers.add(event.pointer);
              final held = _heldPad;
              if (editing || held == null || held == i) {
                _heldPad ??= i;
                return;
              }
              _runMade = true;
              unawaited(HapticFeedback.selectionClick());
              widget.onSelect((math.min(held, i), math.max(held, i)));
            },
            onPointerUp: (event) => _releasePad(event.pointer, i),
            onPointerCancel: (event) => _releasePad(event.pointer, i),
            child: GestureDetector(
              key: ValueKey('region-pad-${region.id}'),
              // One-handed: long-press a pad to stretch the loop to it.
              onLongPress: editing || widget.selection == null
                  ? null
                  : () {
                      final (a, b) = widget.selection!;
                      unawaited(HapticFeedback.selectionClick());
                      widget.onSelect((math.min(a, i), math.max(b, i)));
                    },
              onTap: () {
                if (_runMade) return;
                unawaited(HapticFeedback.selectionClick());
                if (editing) {
                  widget.onEdit(i);
                  return;
                }
                widget.onSelect(widget.selection == (i, i) ? null : (i, i));
              },
              child: Material(
                color: color,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(MonoPulseRadius.large),
                  side: BorderSide(
                    color: playingHere
                        ? MonoPulseColors.white
                        : selected
                        ? MonoPulseColors.accentOrange
                        : color,
                    width: MonoPulseBorder.bold,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(MonoPulseSpacing.sm),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          banked &&
                                  region.section != null &&
                                  region.name.startsWith(region.section!)
                              ? region.name
                                    .substring(region.section!.length)
                                    .trim()
                              : (region.name.isEmpty ? 'Unnamed' : region.name),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: MonoPulseTypography.bodyLarge.copyWith(
                            color: foreground,
                          ),
                        ),
                        Text(
                          banked && grid != null
                              ? '${_bars(grid, region)} bars'
                              : !region.skip &&
                                    region.lengthMs < (grid?.barMs ?? 2000)
                              ? '⚠ ${(region.lengthMs / 1000).toStringAsFixed(1)} s'
                              : grid == null
                              ? '${_time(region.startMs)}–${_time(region.endMs)}'
                              // Inclusive last bar: 8 bars from bar 1 is 1–8.
                              : 'Bars ${grid.barAt(region.startMs).round() + 1}–${math.max(grid.barAt(region.startMs).round() + 1, grid.barAt(region.endMs).round())}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: MonoPulseTypography.bodySmall.copyWith(
                            color: foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    if (!banked) return pads;
    return Column(
      children: [
        SingleChildScrollView(
          key: const ValueKey('pad-bank-row'),
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: MonoPulseSpacing.lg),
          child: Row(
            children: [
              for (final (index, bank) in banks.indexed)
                Padding(
                  padding: const EdgeInsets.only(right: MonoPulseSpacing.sm),
                  child: Listener(
                    onPointerDown: (event) {
                      _bankPointers.add(event.pointer);
                      final held = _heldBank;
                      if (editing || held == null || held == index) {
                        _heldBank ??= index;
                        return;
                      }
                      _bankRunMade = true;
                      unawaited(HapticFeedback.selectionClick());
                      setState(() => _bankId = widget.regions[bank.$1].id);
                      widget.onSelect((
                        math.min(banks[held].$1, bank.$1),
                        math.max(banks[held].$2, bank.$2),
                      ));
                    },
                    onPointerUp: (event) => _releaseBank(event.pointer, index),
                    onPointerCancel: (event) =>
                        _releaseBank(event.pointer, index),
                    child: GestureDetector(
                      key: ValueKey(
                        'region-bank-${widget.regions[bank.$1].id}',
                      ),
                      onLongPress: editing
                          ? () => widget.onRenameSection(
                              _base(
                                widget.regions[bank.$1].section ??
                                    widget.regions[bank.$1].name,
                              ),
                            )
                          : null,
                      onTap: () {
                        if (_bankRunMade) return;
                        unawaited(HapticFeedback.selectionClick());
                        setState(() => _bankId = widget.regions[bank.$1].id);
                        widget.onSelect(bank);
                      },
                      child: Semantics(
                        button: true,
                        selected: index == active,
                        child: Material(
                          color: regionColor(widget.regions[bank.$1]),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              MonoPulseRadius.large,
                            ),
                            side: BorderSide(
                              color: index == active
                                  ? MonoPulseColors.white
                                  : Colors.transparent,
                              width: MonoPulseBorder.bold,
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(MonoPulseSpacing.md),
                            child: Text(
                              widget.regions[bank.$1].section ??
                                  widget.regions[bank.$1].name,
                              style: MonoPulseTypography.bodyLarge.copyWith(
                                color:
                                    ThemeData.estimateBrightnessForColor(
                                          regionColor(widget.regions[bank.$1]),
                                        ) ==
                                        Brightness.dark
                                    ? MonoPulseColors.white
                                    : MonoPulseColors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: pads),
      ],
    );
  }
}
