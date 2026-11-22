import 'dart:math';
import 'package:flutter/material.dart';
import '../domain/models.dart';

const kBg = Color(0xFF0B0B14), kCard = Color(0xFF171726), kLine = Color(0xFF262640);
const kAmber = Color(0xFFF5B942), kMute = Color(0xFF8D8AA3), kRed = Color(0xFFFF5D6C);
const kGreen = Color(0xFF5EE0A0);

ThemeData buildTheme() => ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: kBg,
      colorScheme: const ColorScheme.dark(primary: kAmber, surface: kCard),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: kBg,
        indicatorColor: kAmber.withOpacity(.2),
      ),
    );

class Panel extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  const Panel(this.child, {super.key, this.borderColor});
  @override
  Widget build(BuildContext c) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor ?? kLine),
        ),
        child: child,
      );
}

class Cap extends StatelessWidget {
  final String t;
  const Cap(this.t, {super.key});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          t.toUpperCase(),
          style: const TextStyle(fontSize: 12, letterSpacing: 1.6, color: kMute),
        ),
      );
}

class Pips extends StatelessWidget {
  final int left, max;
  const Pips(this.left, this.max, {super.key});
  @override
  Widget build(BuildContext c) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 0; i < max; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 450),
              curve: Curves.elasticOut,
              width: i < left ? 14 : 8,
              height: i < left ? 14 : 8,
              margin: EdgeInsets.all(i < left ? 0 : 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < left ? kAmber : kLine,
                boxShadow: i < left
                    ? [BoxShadow(color: kAmber.withOpacity(.6), blurRadius: 10)]
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
                      borderRadius: BorderRadius.circular(4),
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
  const BigButton(this.t, this.onTap, {super.key, this.ghost = false});
  @override
  Widget build(BuildContext c) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: ghost ? null : const LinearGradient(colors: [Color(0xFFFFD37A), kAmber]),
            borderRadius: BorderRadius.circular(20),
            border: ghost ? Border.all(color: kLine) : null,
            boxShadow: ghost
                ? []
                : [BoxShadow(color: kAmber.withOpacity(.35), blurRadius: 24, offset: const Offset(0, 8))],
          ),
          child: Text(
            t,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: ghost ? kMute : const Color(0xFF1B1405),
            ),
          ),
        ),
      );
}
