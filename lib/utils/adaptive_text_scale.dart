import 'package:material_ui/material_ui.dart';

/// Scales text for the viewport while preserving the system's font scaling.
class AdaptiveTextScale extends StatelessWidget {
  const AdaptiveTextScale({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final factor = (shortestSide / 360).clamp(1.0, 1.15);
    final systemScaler = MediaQuery.textScalerOf(context);

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: factor == 1.0
            ? systemScaler
            : _AdaptiveScaler(systemScaler, factor),
      ),
      child: child,
    );
  }
}

class _AdaptiveScaler extends TextScaler {
  const _AdaptiveScaler(this.system, this.factor);

  final TextScaler system;
  final double factor;

  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;

  @Deprecated('Use scale instead.')
  @override
  double get textScaleFactor => system.textScaleFactor * factor;

  @override
  bool operator ==(Object other) =>
      other is _AdaptiveScaler &&
      other.system == system &&
      other.factor == factor;

  @override
  int get hashCode => Object.hash(system, factor);
}
