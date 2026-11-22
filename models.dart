import 'package:flutter/material.dart';

const List<String> kNeetSubjects = [
  'Medicine',
  'Surgery',
  'OBG',
  'Pediatrics',
  'PSM',
  'Pathology',
  'Pharmacology',
  'Microbiology',
  'Anatomy',
  'Physiology',
  'Biochemistry',
  'FMT',
  'ENT',
  'Ophthalmology',
  'Orthopedics',
  'Anesthesia',
  'Radiology',
  'Dermatology',
  'Psychiatry',
  'General',
];

const List<String> kStudyModes = [
  'Reading',
  'QBank',
  'Revision',
  'Grand Test',
];

/// Proven spaced-repetition intervals in days: +1, +3, +7, +21, +45 -> Mastered
const List<int> kSrIntervalsDays = [1, 3, 7, 21, 45];

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
  final bool calibration, completed, phoneMode;
  final String subject;
  final String mode;
  final String note;
  final int mcqs;
  final int correct;
  final int xp;

  SessionRecord({
    this.id,
    required this.start,
    required this.plannedMin,
    required this.intervalSec,
    required this.checks,
    required this.tokensLost,
    required this.calibration,
    required this.completed,
    this.phoneMode = false,
    this.subject = 'General',
    this.mode = 'Reading',
    this.note = '',
    this.mcqs = 0,
    this.correct = 0,
    this.xp = 0,
  });

  int count(FocusState s) => checks.where((c) => c == s).length;

  int get focusedSec => phoneMode
      ? (completed ? plannedMin * 60 : checks.length * intervalSec)
      : count(FocusState.study) * intervalSec;

  double get score {
    if (phoneMode) return completed ? 1.0 : 0.7;
    if (checks.isEmpty) return 0;
    return (count(FocusState.study) + .5 * count(FocusState.neutral)) / checks.length;
  }

  Map<String, Object?> toMap() => {
        'start': start.millisecondsSinceEpoch,
        'planned': plannedMin,
        'iv': intervalSec,
        'checks': checks.map((c) => c.index).join(','),
        'lost': tokensLost,
        'calib': calibration ? 1 : 0,
        'done': completed ? 1 : 0,
        'subject': subject,
        'mode': mode,
        'note': note,
        'mcqs': mcqs,
        'correct': correct,
        'phone_mode': phoneMode ? 1 : 0,
        'xp': xp,
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
      phoneMode: m['phone_mode'] == 1,
      subject: ((m['subject'] as String?)?.isNotEmpty ?? false)
          ? m['subject'] as String
          : 'General',
      mode: ((m['mode'] as String?)?.isNotEmpty ?? false)
          ? m['mode'] as String
          : 'Reading',
      note: (m['note'] as String?) ?? '',
      mcqs: (m['mcqs'] as int?) ?? 0,
      correct: (m['correct'] as int?) ?? 0,
      xp: (m['xp'] as int?) ?? 0,
    );
  }
}

class RevisionItem {
  final int? id;
  final String subject;
  final String topic;
  final int stage; // 0..4 = active intervals, >=5 = Mastered
  final DateTime due;
  final DateTime created;
  final bool highYield;
  final int doneCount;

  RevisionItem({
    this.id,
    required this.subject,
    required this.topic,
    required this.stage,
    required this.due,
    required this.created,
    this.highYield = false,
    this.doneCount = 0,
  });

  bool get isMastered => stage >= kSrIntervalsDays.length;

  bool get isDueToday {
    if (isMastered) return false;
    final now = DateTime.now();
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return !due.isAfter(endOfToday);
  }

  String get stageLabel => isMastered
      ? 'Mastered'
      : 'R${stage + 1} · +${kSrIntervalsDays[stage]}d';

  Map<String, Object?> toMap() => {
        'subject': subject,
        'topic': topic,
        'stage': stage,
        'due': due.millisecondsSinceEpoch,
        'created': created.millisecondsSinceEpoch,
        'high_yield': highYield ? 1 : 0,
        'done_count': doneCount,
      };

  static RevisionItem fromMap(Map<String, Object?> m) => RevisionItem(
        id: m['id'] as int?,
        subject: (m['subject'] as String?) ?? 'General',
        topic: (m['topic'] as String?) ?? '',
        stage: (m['stage'] as int?) ?? 0,
        due: DateTime.fromMillisecondsSinceEpoch((m['due'] as int?) ?? 0),
        created: DateTime.fromMillisecondsSinceEpoch((m['created'] as int?) ?? 0),
        highYield: m['high_yield'] == 1,
        doneCount: (m['done_count'] as int?) ?? 0,
      );
}
