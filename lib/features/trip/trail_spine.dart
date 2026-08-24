import 'package:flutter/material.dart';

import '../../core/audio/fp_feedback.dart';
import '../../core/design/fp_colors.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../domain/calc/trip_analysis.dart';
import '../../shared/widgets/fp_art.dart';
import 'workspace_section.dart';

/// The app's navigation: a trail running down the side of the screen with a
/// marker for every stage of the plan. Filled markers mean the stage has data,
/// so the route to a finished trip card is visible at a glance.
class TrailSpine extends StatelessWidget {
  const TrailSpine({
    required this.analysis,
    required this.current,
    required this.onSelect,
    super.key,
  });

  final TripAnalysis analysis;
  final WorkspaceSection current;
  final ValueChanged<WorkspaceSection> onSelect;

  static const width = 76.0;
  static const _nodeSize = 44.0;

  @override
  Widget build(BuildContext context) {
    final sections = WorkspaceSection.values;
    final filled = {
      for (final section in sections) section: section.isFilled(analysis),
    };

    return SizedBox(
      width: width,
      child: CustomPaint(
        painter: _TrailPainter(
          count: sections.length,
          nodeSize: _nodeSize,
          reachedIndex: sections.indexOf(current),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (final section in sections)
              _Node(
                section: section,
                isCurrent: section == current,
                isFilled: filled[section] ?? false,
                isSummit: section == sections.last,
                onTap: () {
                  FpFeedback.instance.play(FpSound.screenOpen);
                  onSelect(section);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Node extends StatelessWidget {
  const _Node({
    required this.section,
    required this.isCurrent,
    required this.isFilled,
    required this.isSummit,
    required this.onTap,
  });

  final WorkspaceSection section;
  final bool isCurrent;
  final bool isFilled;
  final bool isSummit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = section.accent;

    return Semantics(
      button: true,
      selected: isCurrent,
      label: '${section.title}${isFilled ? ', has data' : ', empty'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: FpRadius.tileAll,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: FpMotion.base,
                curve: FpMotion.curve,
                width: TrailSpine._nodeSize,
                height: TrailSpine._nodeSize,
                decoration: BoxDecoration(
                  color: isCurrent ? Colors.white : FpColors.canvas,
                  shape: isSummit ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isSummit ? FpRadius.tileAll : null,
                  border: Border.all(
                    color: isCurrent
                        ? accent
                        : (isFilled ? FpColors.outlineStrong : FpColors.outline),
                    width: isCurrent ? 2 : 1,
                  ),
                  boxShadow: isCurrent ? FpShadow.soft : null,
                ),
                child: Center(
                  child: FpArt(
                    section.art,
                    size: 26,
                    opacity: isCurrent || isFilled ? 1 : 0.45,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                section.shortLabel,
                style: FpTypography.caption.copyWith(
                  fontSize: 10,
                  height: 1.1,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                  color: isCurrent ? accent : FpColors.graphiteSoft,
                ),
              ),
              AnimatedContainer(
                duration: FpMotion.base,
                margin: const EdgeInsets.only(top: 2),
                width: isFilled ? 14 : 0,
                height: 2.5,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: FpRadius.pillAll,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The dashed path linking the markers. Everything up to the current stage is
/// drawn solid, the rest stays dashed like an unwalked trail.
class _TrailPainter extends CustomPainter {
  const _TrailPainter({
    required this.count,
    required this.nodeSize,
    required this.reachedIndex,
  });

  final int count;
  final double nodeSize;
  final int reachedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    if (count < 2) return;

    final x = size.width / 2;
    final slotHeight = size.height / count;
    final firstY = slotHeight / 2;
    final lastY = size.height - slotHeight / 2;
    final reachedY = firstY + (lastY - firstY) * (reachedIndex / (count - 1));

    final walked = Paint()
      ..color = FpColors.forestSoft
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final ahead = Paint()
      ..color = FpColors.outlineStrong
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(x, firstY), Offset(x, reachedY), walked);

    const dash = 5.0;
    const gap = 5.0;
    var y = reachedY;
    while (y < lastY) {
      final end = (y + dash).clamp(reachedY, lastY);
      canvas.drawLine(Offset(x, y), Offset(x, end), ahead);
      y += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) =>
      old.reachedIndex != reachedIndex || old.count != count;
}
