import 'package:flutter/material.dart';

enum FocusState { study, neutral, distraction, absent }

extension FocusX on FocusState {
  String get label => const {
        FocusState.study: 'Study',
        FocusState.neutral: 'Neutral',
        FocusState.distraction: 'Distracted',
        FocusState.absent: 'Absent'
      }[this]!;

  int get cost => const {
        FocusState.study: 0,
        FocusState.neutral: 0,
        FocusState.distraction: 1,
        FocusState.absent: 2
      }[this]!;

  Color get color => const {
        FocusState.study: Color(0xFF5EE0A0),
        FocusState.neutral: Color(0xFF7AA7FF),
        FocusState.distraction: Color(0xFFFF9F5A),
        FocusState.absent: Color(0xFFFF5D6C)
      }[this]!;

  String get message => const {
        FocusState.study: 'Locked in. Full credit.',
        FocusState.neutral: 'Inconclusive. No penalty: I never guess.',
        FocusState.distraction: 'Attention broke. -1 token.',
        FocusState.absent: 'Seat empty. -2 tokens.'
      }[this]!;
}

class SessionRecord {
  final int? id;
  final DateTime start;
  final int plannedMin, intervalSec, tokensLost;
  final List<FocusState> checks;
  final bool calibration, completed;

  SessionRecord({
    this.id,
    required this.start,
    required this.plannedMin,
    required this.intervalSec,
    required this.checks,
    required this.tokensLost,
    required this.calibration,
    required this.completed,
  });

  int count(FocusState s) => checks.where((c) => c == s).length;
  int get focusedSec => count(FocusState.study) * intervalSec;
  double get score => checks.isEmpty
      ? 0
      : (count(FocusState.study) + .5 * count(FocusState.neutral)) / checks.length;

  Map<String, Object?> toMap() => {
        'start': start.millisecondsSinceEpoch,
        'planned': plannedMin,
        'iv': intervalSec,
        'checks': checks.map((c) => c.index).join(','),
        'lost': tokensLost,
        'calib': calibration ? 1 : 0,
        'done': completed ? 1 : 0,
      };

  static SessionRecord fromMap(Map<String, Object?> m) {
    final rawChecks = (m['checks'] as String?) ?? '';
    final parsed = <FocusState>[];
    if (rawChecks.isNotEmpty) {
      for (final part in rawChecks.split(',')) {
        final idx = int.tryParse(part);
        if (idx != null && idx >= 0 && idx < FocusState.values.length) {
          parsed.add(FocusState.values[idx]);
        }
      }
    }
    return SessionRecord(
      id: m['id'] as int?,
      start: DateTime.fromMillisecondsSinceEpoch((m['start'] as int?) ?? 0),
      plannedMin: (m['planned'] as int?) ?? 0,
      intervalSec: (m['iv'] as int?) ?? 60,
      checks: parsed,
      tokensLost: (m['lost'] as int?) ?? 0,
      calibration: m['calib'] == 1,
      completed: m['done'] == 1,
    );
  }
}
