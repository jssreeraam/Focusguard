import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/models.dart';

// Quabble-inspired full-volume warm pastel palette
const kBg = Color(0xFFFAF8F2);        // Warm cream canvas
const kCard = Color(0xFFFFFFFF);      // Crisp white card
const kLine = Color(0xFFE6E1D6);      // Soft warm hairline
const kInk = Color(0xFF232421);       // Bold dark charcoal ink
const kMute = Color(0xFF6B6D65);      // Soft olive-slate caption
const kAmber = Color(0xFFF28C38);     // Warm tangerine accent
const kGreen = Color(0xFF4E8F5B);     // Cozy sage-emerald
const kRed = Color(0xFFD9534F);       // Warm coral-red
const kBlue = Color(0xFF4A82B5);      // Calm sky-blue ink

// Pastel Bento Card Fills
const kSage = Color(0xFFDCEFD2);      // Sage mint card
const kSky = Color(0xFFDCEEFB);       // Misty sky card
const kPeach = Color(0xFFFDE3CF);     // Warm peach card
const kLavender = Color(0xFFEAE2F8);  // Soft lavender card
const kButter = Color(0xFFFDF2C5);    // Warm butter card
const kNight = Color(0xFF2B3544);     // Cozy midnight slate card

String fmtMins(int totalMin) {
  if (totalMin <= 0) return '0m';
  final h = totalMin ~/ 60;
  final m = totalMin % 60;
  if (h == 0) return '${m}m';
  if (m == 0) return '${h}h';
  return '${h}h ${m}m';
}

String aspirantRank(int totalHours) {
  if (totalHours >= 300) return 'AIR 1 CONTENDER';
  if (totalHours >= 150) return 'AIIMS RANKER';
  if (totalHours >= 75) return 'CHIEF RESIDENT';
  if (totalHours >= 25) return 'RESIDENT';
  return 'INTERN WARDEN';
}

ThemeData buildTheme() => ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      scaffoldBackgroundColor: kBg,
      colorScheme: const ColorScheme.light(
        primary: kInk,
        secondary: kAmber,
        surface: kCard,
        onSurface: kInk,
      ),
      textTheme: const TextTheme(
        bodyMedium: TextStyle(color: kInk),
        bodyLarge: TextStyle(color: kInk),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white.withOpacity(.85),
        selectedColor: kInk,
        labelStyle: const TextStyle(color: kInk, fontWeight: FontWeight.w600, fontSize: 13),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
          side: const BorderSide(color: kLine),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 6,
        indicatorColor: kSage,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kInk),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected) ? kInk : kMute,
          ),
        ),
      ),
    );

class Panel extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;
  const Panel(this.child, {super.key, this.color, this.borderColor});
  @override
  Widget build(BuildContext c) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: color ?? kCard,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: borderColor ?? kLine.withOpacity(.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: child,
      );
}

class Cap extends StatelessWidget {
  final String t;
  final Color? color;
  const Cap(this.t, {super.key, this.color});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          t.toUpperCase(),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: color ?? kMute,
          ),
        ),
      );
}

class Pips extends StatelessWidget {
  final int left, max;
  const Pips(this.left, this.max, {super.key});
  @override
  Widget build(BuildContext c) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (var i = 0; i < max; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              width: i < left ? 16 : 10,
              height: i < left ? 16 : 10,
              margin: EdgeInsets.all(i < left ? 0 : 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < left ? kAmber : kLine,
                boxShadow: i < left
                    ? [BoxShadow(color: kAmber.withOpacity(.45), blurRadius: 8)]
                    : [],
              ),
            )
        ],
      );
}

class Timeline extends StatelessWidget {
  final List<FocusState> items;
  const Timeline(this.items, {super.key});
  @override
  Widget build(BuildContext c) => SizedBox(
        height: 38,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final s in items)
              Expanded(
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (_, v, __) => Container(
                    height: 38.0 *
                        min(v, 1.2) *
                        const {
                          FocusState.study: 1.0,
                          FocusState.neutral: .6,
                          FocusState.distraction: .45,
                          FocusState.absent: .28
                        }[s]!,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: s.color,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              )
          ],
        ),
      );
}

class BigButton extends StatelessWidget {
  final String t;
  final VoidCallback? onTap;
  final bool ghost;
  final Color? fill;
  const BigButton(this.t, this.onTap, {super.key, this.ghost = false, this.fill});
  @override
  Widget build(BuildContext c) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ghost ? Colors.white.withOpacity(.85) : (fill ?? kInk),
            borderRadius: BorderRadius.circular(99),
            border: ghost ? Border.all(color: kLine, width: 1.2) : null,
            boxShadow: ghost
                ? []
                : [BoxShadow(color: Colors.black.withOpacity(.14), blurRadius: 16, offset: const Offset(0, 6))],
          ),
          child: Text(
            t,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: ghost ? kInk : Colors.white,
            ),
          ),
        ),
      );
}

/// Animated 0% -> 100% Monthly Citadel Monument (Pastel Sage & Warm Gold).
class CitadelWidget extends StatelessWidget {
  final double progress;
  final int cracks;
  final double height;
  const CitadelWidget({
    super.key,
    required this.progress,
    this.cracks = 0,
    this.height = 155,
  });

  String get _tierName {
    if (progress >= 1.0) return 'GOLDEN CROWN COMPLETE';
    if (progress >= 0.75) return 'HIGH-YIELD SPIRE';
    if (progress >= 0.50) return 'STUDY HALLS';
    if (progress >= 0.25) return 'PILLARS OF DISCIPLINE';
    return 'FOUNDATION';
  }

  @override
  Widget build(BuildContext context) {
    final p = progress.clamp(0.0, 1.0);
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: height,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: p),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (_, val, __) => CustomPaint(
              painter: _CitadelPainter(val, cracks),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _tierName,
              style: const TextStyle(color: kInk, fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w700),
            ),
            Text(
              '${(p * 100).round()}%${cracks > 0 ? ' · $cracks crack(s)' : ''}',
              style: TextStyle(
                color: cracks > 0 ? kRed : kGreen,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CitadelPainter extends CustomPainter {
  final double p;
  final int cracks;
  _CitadelPainter(this.p, this.cracks);

  @override
  void paint(Canvas cv, Size s) {
    final cx = s.width / 2;
    final base = s.height - 8;
    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = kInk.withOpacity(.35);
    final glow = Paint()
      ..color = kAmber.withOpacity(0.22 + 0.30 * p)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    if (p > 0.05) {
      cv.drawCircle(Offset(cx, base - s.height * 0.45 * p), 38 + 24 * p, glow);
    }

    void drawTier(double threshold, Rect rect, {bool spire = false}) {
      final local = ((p - threshold) / 0.25).clamp(0.0, 1.0);
      final bg = Paint()..color = Colors.white.withOpacity(.75);
      final gold = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xFFE07A22), kAmber, Color(0xFFFFD57E)],
        ).createShader(rect);

      if (!spire) {
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
        cv.drawRRect(rr, bg);
        if (local > 0) {
          final filled = Rect.fromLTRB(
            rect.left,
            rect.bottom - rect.height * local,
            rect.right,
            rect.bottom,
          );
          cv.drawRRect(RRect.fromRectAndRadius(filled, const Radius.circular(6)), gold);
        }
        cv.drawRRect(rr, outline);
      } else {
        final path = Path()
          ..moveTo(rect.left, rect.bottom)
          ..lineTo(cx, rect.top)
          ..lineTo(rect.right, rect.bottom)
          ..close();
        cv.drawPath(path, bg);
        if (local > 0) {
          cv.save();
          cv.clipRect(Rect.fromLTRB(
            rect.left,
            rect.bottom - rect.height * local,
            rect.right,
            rect.bottom,
          ));
          cv.drawPath(path, gold);
          cv.restore();
        }
        cv.drawPath(path, outline);
      }
    }

    drawTier(0.0, Rect.fromCenter(center: Offset(cx, base - 12), width: s.width * 0.78, height: 22));
    for (final dx in [-s.width * 0.26, -s.width * 0.09, s.width * 0.09, s.width * 0.26]) {
      drawTier(0.25, Rect.fromCenter(center: Offset(cx + dx, base - 44), width: 18, height: 40));
    }
    drawTier(0.50, Rect.fromCenter(center: Offset(cx, base - 78), width: s.width * 0.50, height: 28));
    drawTier(0.75, Rect.fromLTWH(cx - 26, base - 138, 52, 46), spire: true);

    if (p >= 0.99) {
      cv.drawCircle(Offset(cx, base - 144), 6, Paint()..color = kAmber);
    }

    if (cracks > 0) {
      final crackPaint = Paint()
        ..color = kRed
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke;
      final cp = Path()
        ..moveTo(cx - 12, base - 2)
        ..lineTo(cx - 4, base - 14)
        ..lineTo(cx - 10, base - 22);
      cv.drawPath(cp, crackPaint);
    }
  }

  @override
  bool shouldRepaint(_CitadelPainter o) => o.p != p || o.cracks != cracks;
}
