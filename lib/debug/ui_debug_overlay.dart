import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class UiDebugOverlay extends StatefulWidget {
  const UiDebugOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<UiDebugOverlay> createState() => _UiDebugOverlayState();
}

class _UiDebugOverlayState extends State<UiDebugOverlay> {
  var _panelOpen = false;
  var _showLayoutBounds = false;
  var _showTextBaselines = false;
  var _showGrid = false;
  var _showCenterLines = false;
  var _showSafeArea = false;

  @override
  void dispose() {
    debugPaintSizeEnabled = false;
    debugPaintBaselinesEnabled = false;
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f10) {
      setState(() => _panelOpen = !_panelOpen);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _setLayoutBounds(bool value) {
    setState(() => _showLayoutBounds = value);
    debugPaintSizeEnabled = value;
    _repaintRenderTree();
  }

  void _setTextBaselines(bool value) {
    setState(() => _showTextBaselines = value);
    debugPaintBaselinesEnabled = value;
    _repaintRenderTree();
  }

  void _repaintRenderTree() {
    void markNeedsPaint(RenderObject child) {
      child.markNeedsPaint();
      child.visitChildren(markNeedsPaint);
    }

    for (final view in RendererBinding.instance.renderViews) {
      view.markNeedsPaint();
      view.visitChildren(markNeedsPaint);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final media = MediaQuery.of(context);
          final safeArea = media.padding;
          final debugPanelWidth = math.min(
            340.0,
            math.max(200.0, constraints.maxWidth - 24),
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (_showGrid || _showCenterLines || _showSafeArea)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: const ValueKey('ui-debug-guides'),
                      painter: _UiDebugGuidesPainter(
                        showGrid: _showGrid,
                        showCenterLines: _showCenterLines,
                        showSafeArea: _showSafeArea,
                        safeArea: safeArea,
                      ),
                    ),
                  ),
                ),
              if (_panelOpen)
                Positioned(
                  right: 12,
                  bottom: 58,
                  child: SafeArea(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: debugPanelWidth,
                        maxHeight: constraints.maxHeight * .8,
                      ),
                      child: _buildPanel(context, media, constraints),
                    ),
                  ),
                ),
              Positioned(
                right: 12,
                bottom: 12,
                child: SafeArea(
                  child: Material(
                    color: Theme.of(context).colorScheme.inverseSurface,
                    shape: const CircleBorder(),
                    elevation: 5,
                    child: Semantics(
                      label: _panelOpen ? '关闭 UI 调试' : 'UI 调试 (F10)',
                      button: true,
                      child: IconButton(
                        key: const ValueKey('ui-debug-toggle'),
                        onPressed: () =>
                            setState(() => _panelOpen = !_panelOpen),
                        color: Theme.of(context).colorScheme.onInverseSurface,
                        icon: const Icon(Icons.bug_report_outlined),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPanel(
    BuildContext context,
    MediaQueryData media,
    BoxConstraints constraints,
  ) {
    final safeArea = media.padding;
    final textTheme = Theme.of(context).textTheme;
    final metrics = [
      '视口  ${media.size.width.toStringAsFixed(0)} × '
          '${media.size.height.toStringAsFixed(0)} dp',
      'DPR  ${media.devicePixelRatio.toStringAsFixed(2)}',
      '安全区  左 ${safeArea.left.toStringAsFixed(0)}  '
          '上 ${safeArea.top.toStringAsFixed(0)}  '
          '右 ${safeArea.right.toStringAsFixed(0)}  '
          '下 ${safeArea.bottom.toStringAsFixed(0)} dp',
      '文字缩放  ${media.textScaler.scale(1).toStringAsFixed(2)}×',
      '布局约束  ${constraints.maxWidth.toStringAsFixed(0)} × '
          '${constraints.maxHeight.toStringAsFixed(0)} dp',
    ];

    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: .98),
      elevation: 12,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text('UI 调试', style: textTheme.titleSmall)),
                Text('F10', style: textTheme.labelSmall),
              ],
            ),
            const Divider(height: 16),
            for (final metric in metrics)
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  metric,
                  style: textTheme.labelSmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            const Divider(height: 16),
            _DebugSwitch(
              key: const ValueKey('ui-debug-layout-bounds'),
              title: '布局边界',
              value: _showLayoutBounds,
              onChanged: _setLayoutBounds,
            ),
            _DebugSwitch(
              key: const ValueKey('ui-debug-text-baselines'),
              title: '文字基线',
              value: _showTextBaselines,
              onChanged: _setTextBaselines,
            ),
            _DebugSwitch(
              key: const ValueKey('ui-debug-grid'),
              title: '8dp 对齐网格',
              value: _showGrid,
              onChanged: (value) => setState(() => _showGrid = value),
            ),
            _DebugSwitch(
              key: const ValueKey('ui-debug-centers'),
              title: '屏幕中心线',
              value: _showCenterLines,
              onChanged: (value) => setState(() => _showCenterLines = value),
            ),
            _DebugSwitch(
              key: const ValueKey('ui-debug-safe-area'),
              title: '安全区域',
              value: _showSafeArea,
              onChanged: (value) => setState(() => _showSafeArea = value),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugSwitch extends StatelessWidget {
  const _DebugSwitch({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.bodySmall),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _UiDebugGuidesPainter extends CustomPainter {
  const _UiDebugGuidesPainter({
    required this.showGrid,
    required this.showCenterLines,
    required this.showSafeArea,
    required this.safeArea,
  });

  final bool showGrid;
  final bool showCenterLines;
  final bool showSafeArea;
  final EdgeInsets safeArea;

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) {
      final paint = Paint()
        ..color = const Color(0x552F73C8)
        ..strokeWidth = .5;
      for (double x = 0; x <= size.width; x += 8) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
      for (double y = 0; y <= size.height; y += 8) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }

    if (showCenterLines) {
      final paint = Paint()
        ..color = const Color(0xCCEA4E4E)
        ..strokeWidth = 1;
      final center = Offset(size.width / 2, size.height / 2);
      canvas.drawLine(
        Offset(center.dx, 0),
        Offset(center.dx, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(0, center.dy),
        Offset(size.width, center.dy),
        paint,
      );
      canvas.drawCircle(center, 4, paint..style = PaintingStyle.fill);
    }

    if (showSafeArea) {
      final paint = Paint()..color = const Color(0x33E64B4B);
      if (safeArea.left > 0) {
        canvas.drawRect(Rect.fromLTWH(0, 0, safeArea.left, size.height), paint);
      }
      if (safeArea.top > 0) {
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, safeArea.top), paint);
      }
      if (safeArea.right > 0) {
        canvas.drawRect(
          Rect.fromLTWH(
            size.width - safeArea.right,
            0,
            safeArea.right,
            size.height,
          ),
          paint,
        );
      }
      if (safeArea.bottom > 0) {
        canvas.drawRect(
          Rect.fromLTWH(
            0,
            size.height - safeArea.bottom,
            size.width,
            safeArea.bottom,
          ),
          paint,
        );
      }
      if (safeArea.left > 0) {
        canvas.drawRect(Rect.fromLTWH(0, 0, safeArea.left, size.height), paint);
      }
      if (safeArea.right > 0) {
        canvas.drawRect(
          Rect.fromLTWH(
            size.width - safeArea.right,
            0,
            safeArea.right,
            size.height,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _UiDebugGuidesPainter oldDelegate) =>
      showGrid != oldDelegate.showGrid ||
      showCenterLines != oldDelegate.showCenterLines ||
      showSafeArea != oldDelegate.showSafeArea ||
      safeArea != oldDelegate.safeArea;
}
