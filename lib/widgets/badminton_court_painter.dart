import 'package:flutter/material.dart';

/// 繪製羽球雙打場地示意圖。
///
/// 座標說明（直式）：
///   上半場 = 雙打隊伍 A，下半場 = 雙打隊伍 B；橫跨中間的粗線是球網。
class BadmintonCourtPainter extends CustomPainter {
  BadmintonCourtPainter({
    this.courtColor = const Color(0xFF2E7D32),
    this.lineColor = Colors.white,
  });

  final Color courtColor;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = courtColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // 外框（雙打邊界）
    canvas.drawRect(Rect.fromLTWH(4, 4, size.width - 8, size.height - 8), line);

    // 雙打後發球線（上下各一條）
    final backServiceTop = size.height * 0.12;
    final backServiceBottom = size.height * 0.88;
    canvas.drawLine(
      Offset(4, backServiceTop),
      Offset(size.width - 4, backServiceTop),
      line,
    );
    canvas.drawLine(
      Offset(4, backServiceBottom),
      Offset(size.width - 4, backServiceBottom),
      line,
    );

    // 短發球線（上下各一條，離網較近）
    final shortServiceTop = size.height * 0.38;
    final shortServiceBottom = size.height * 0.62;
    canvas.drawLine(
      Offset(4, shortServiceTop),
      Offset(size.width - 4, shortServiceTop),
      line,
    );
    canvas.drawLine(
      Offset(4, shortServiceBottom),
      Offset(size.width - 4, shortServiceBottom),
      line,
    );

    // 中線：從短發球線到後發球線（上下兩段）
    final centerX = size.width / 2;
    canvas.drawLine(
      Offset(centerX, backServiceTop),
      Offset(centerX, shortServiceTop),
      line,
    );
    canvas.drawLine(
      Offset(centerX, shortServiceBottom),
      Offset(centerX, backServiceBottom),
      line,
    );

    // 球網（水平中線，粗）
    final netPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(4, size.height / 2),
      Offset(size.width - 4, size.height / 2),
      netPaint,
    );
    // 網上的小點做視覺提示
    final netDot = Paint()..color = lineColor.withValues(alpha: 0.6);
    const dotSpacing = 12.0;
    for (double x = 8; x < size.width - 8; x += dotSpacing) {
      canvas.drawCircle(Offset(x, size.height / 2), 1.2, netDot);
    }
  }

  @override
  bool shouldRepaint(covariant BadmintonCourtPainter oldDelegate) =>
      oldDelegate.courtColor != courtColor ||
      oldDelegate.lineColor != lineColor;
}
