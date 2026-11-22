import 'package:material_ui/material_ui.dart';

/// A single-line label with space reserved for its longest expected value.
class StableSlotText extends StatelessWidget {
  const StableSlotText(
    this.label, {
    required this.sample,
    this.style,
    this.alignment = Alignment.center,
    this.semanticsLabel,
    super.key,
  });

  final String label;
  final String sample;
  final TextStyle? style;
  final Alignment alignment;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final painter = TextPainter(
      text: TextSpan(
        text: sample,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: direction,
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width.ceilToDouble();
    painter.dispose();
    return FittedBox(
      alignment: alignment,
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: width,
        child: Text(
          label,
          semanticsLabel: semanticsLabel,
          textAlign: alignment.x < 0
              ? TextAlign.left
              : alignment.x > 0
              ? TextAlign.right
              : TextAlign.center,
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
