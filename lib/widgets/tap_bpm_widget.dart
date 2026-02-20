import 'package:flutter/material.dart';
import '../services/metronome_service.dart';

/// Tap BPM widget - calculate tempo by tapping
class TapBPMWidget extends StatefulWidget {
  const TapBPMWidget({super.key});

  @override
  State<TapBPMWidget> createState() => _TapBPMWidgetState();
}

class _TapBPMWidgetState extends State<TapBPMWidget> {
  final List<DateTime> _taps = [];
  int? _calculatedBPM;
  final MetronomeService _metronome = MetronomeService();

  void _handleTap() {
    final now = DateTime.now();
    
    // Add tap
    setState(() {
      _taps.add(now);
      
      // Keep only last 8 taps
      if (_taps.length > 8) {
        _taps.removeAt(0);
      }
      
      // Calculate BPM if we have at least 2 taps
      if (_taps.length >= 2) {
        final intervals = <int>[];
        for (int i = 1; i < _taps.length; i++) {
          intervals.add(_taps[i].difference(_taps[i - 1]).inMilliseconds);
        }
        
        // Average interval
        final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
        
        // Convert to BPM
        final bpm = (60000 / avgInterval).round();
        
        // Validate BPM range
        if (bpm >= 40 && bpm <= 220) {
          _calculatedBPM = bpm;
        }
      }
    });
  }

  void _applyBPM() {
    if (_calculatedBPM != null) {
      _metronome.setBpm(_calculatedBPM!);
      setState(() {
        _taps.clear();
        _calculatedBPM = null;
      });
    }
  }

  void _reset() {
    setState(() {
      _taps.clear();
      _calculatedBPM = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tap button
            GestureDetector(
              onTap: _handleTap,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _calculatedBPM != null 
                      ? Colors.green.shade100 
                      : Colors.blue.shade100,
                  border: Border.all(
                    color: _calculatedBPM != null 
                        ? Colors.green 
                        : Colors.blue,
                    width: 3,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.touch_app, size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'TAP',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _calculatedBPM != null 
                            ? Colors.green.shade700 
                            : Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // BPM display
            if (_calculatedBPM != null) ...[
              Text(
                '$_calculatedBPM BPM',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_taps.length} taps',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),
              
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Apply'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _applyBPM,
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Reset'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: _reset,
                  ),
                ],
              ),
            ] else ...[
              const Text(
                'Tap to calculate tempo',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
