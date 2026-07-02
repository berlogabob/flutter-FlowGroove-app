import 'package:intl/intl.dart';

import '../../../models/rehearsal.dart';

/// "Sat, Jul 4 · 19:00–21:00" for a candidate slot (device local time).
String formatSlotRange(CandidateSlot slot) {
  final day = DateFormat('EEE, MMM d').format(slot.startTime);
  final start = DateFormat('HH:mm').format(slot.startTime);
  final end = DateFormat('HH:mm').format(slot.endTime);
  return '$day · $start–$end';
}
