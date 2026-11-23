import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'copy.dart';

const studioBackground = Color(0xff161917);
const studioSurface = Color(0xff212623);
const studioBorder = Color(0xff39423b);
const studioAccent = Color(0xffcee98e);
const trackColors = [
  studioAccent,
  Color(0xff9bb2ed),
  Color(0xffefa991),
  Color(0xffe5ca91),
  Color(0xffbcaaf0),
  Color(0xff8dd4be),
  Color(0xffedafc9),
  Color(0xffb4c8d9),
];

final studioTheme = ThemeData(
  colorScheme: const ColorScheme.dark(
    primary: studioAccent,
    onPrimary: Color(0xff192314),
    surface: studioSurface,
    onSurface: Color(0xffeef3e9),
    onSurfaceVariant: Color(0xffb7c2b6),
    outline: Color(0xff778579),
    outlineVariant: studioBorder,
    secondary: Color(0xffa5bcec),
    onSecondary: Color(0xff182542),
  ),
  scaffoldBackgroundColor: studioBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: studioBackground,
    scrolledUnderElevation: 0,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: studioSurface,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
  ),
);

class StudioPanel extends StatelessWidget {
  const StudioPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: studioSurface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: studioBorder),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class StudioList extends StatelessWidget {
  const StudioList({super.key, this.title, required this.children});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 24),
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
          ],
          ...children,
        ],
      ),
    ),
  );
}

class Waveform extends StatelessWidget {
  const Waveform({
    super.key,
    required this.levels,
    this.height = 88,
    this.color = studioAccent,
    this.selection,
  });

  final List<double> levels;
  final double height;
  final Color color;
  final RangeValues? selection;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    width: double.infinity,
    child: CustomPaint(painter: _WaveformPainter(levels, color, selection)),
  );
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter(this.levels, this.color, this.selection);

  final List<double> levels;
  final Color color;
  final RangeValues? selection;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.height / 2;
    canvas.drawLine(
      Offset(0, center),
      Offset(size.width, center),
      Paint()..color = studioBorder,
    );
    final range = selection;
    if (range != null) {
      final start = range.start * size.width;
      final end = range.end * size.width;
      canvas.drawRect(
        Rect.fromLTRB(start, 0, end, size.height),
        Paint()..color = color.withValues(alpha: .12),
      );
    }
    if (levels.isEmpty) return;
    final interval = size.width / levels.length;
    final paint = Paint()
      ..strokeWidth = math.max(1, interval * .55)
      ..strokeCap = StrokeCap.round;
    for (var index = 0; index < levels.length; index++) {
      final position = (index + .5) / levels.length;
      final x = position * size.width;
      final amplitude = math.max(1.0, levels[index] * center * .9);
      final selected =
          range == null || (position >= range.start && position <= range.end);
      paint.color = selected ? color : color.withValues(alpha: .37);
      canvas.drawLine(
        Offset(x, center - amplitude),
        Offset(x, center + amplitude),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.levels != levels || old.color != color || old.selection != selection;
}

Future<bool> confirmDelete(
  BuildContext context,
  L title, [
  String? name,
]) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: Text(title(dialog)),
          content: name == null ? null : Text(name),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: Text(L.cancel(dialog)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: Text(L.remove(dialog)),
            ),
          ],
        ),
      ) ==
      true;
}
