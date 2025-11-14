import 'package:flutter/material.dart';

import '../pages/platform_view_page_controller.dart';

class ARPainter extends CustomPainter {
  PlatformViewPageController pageController;

  ARPainter({required this.pageController});

  @override
  void paint(Canvas canvas, Size size) {
    if (pageController.arData.shouldMoveBackward) return;

    final points = pageController.arData.bottomPointsPositions;
    final topPoints = pageController.arData.topPointsPositions;
    final distances = pageController.arData.distances;

    final topVisiblePointIds = pageController.arData.topVisiblePointIds;
    final bottomVisiblePointIds = pageController.arData.bottomVisiblePointIds;

    final cameraPosition = pageController.arData.cameraPosition;
    final prospectivePoint = pageController.arData.prospectiveScreenPosition;

    final shouldMoveToSide = pageController.shouldMoveSideways;

    final prospectivePaint = Paint()
      ..color = Colors.amber
      ..strokeWidth = 4;
    final pointsPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 4;

    final linePaint = Paint()
      ..color = pointsPaint.color
      ..strokeWidth = 4;

    // 未計測時のポイント
    if (points.isEmpty && prospectivePoint != null && cameraPosition != null) {
      final rect = Rect.fromCircle(center: prospectivePoint, radius: 4);
      canvas.drawOval(rect, prospectivePaint);
    }

    // 計測済みの点間のラインと距離ラベル
    if (bottomVisiblePointIds.length >= 2) {
      for (var i = 1; i < bottomVisiblePointIds.length; i++) {
        final p0 = points[bottomVisiblePointIds[i - 1]];
        final p1 = points[bottomVisiblePointIds[i]];
        final distance = distances[bottomVisiblePointIds[i - 1]];

        canvas.drawLine(p0, p1, linePaint);

        if (i <= 2) {
          final labelCenter = (p0 + p1) / 2;

          final textPainter = TextPainter(
            text: TextSpan(
              text: '${(distance * 100).toStringAsFixed(1)} cm',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          );
          textPainter.layout();

          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: labelCenter,
                width: textPainter.size.width + textPainter.size.height + 4,
                height: textPainter.size.height + 4,
              ),
              Radius.circular(textPainter.size.height / 2 + 2),
            ),
            linePaint,
          );
          textPainter.paint(
            canvas,
            labelCenter - Offset(textPainter.width / 2, textPainter.height / 2),
          );
        }
        if (i == 3) {
          final p2 = points[bottomVisiblePointIds[0]];
          final p3 = points[bottomVisiblePointIds[3]];
          canvas.drawLine(p2, p3, linePaint);
        }
      }
    }

    // 候補点までの線
    if (points.isNotEmpty &&
        points.length <= 4 &&
        prospectivePoint != null &&
        !shouldMoveToSide &&
        pageController.distanceToProspective != null) {
      final p0 = points[pageController.arData.nearestPointId!];
      final p1 = prospectivePoint;
      // 候補点までの線
      canvas.drawLine(p0, p1, prospectivePaint);
    }

    // 計測済みの点
    for (final i in bottomVisiblePointIds) {
      final point = points[i];
      final pointPath = Path()
        ..addOval(Rect.fromCircle(center: point, radius: 4));
      canvas.drawPath(pointPath, pointsPaint);
    }

    // 候補点
    if (points.isNotEmpty &&
        points.length < 5 &&
        prospectivePoint != null &&
        !shouldMoveToSide &&
        pageController.distanceToProspective != null) {
      final point2 = prospectivePoint;
      final distance = pageController.distanceToProspective!;

      // 候補点
      canvas.drawOval(
          Rect.fromCircle(center: point2, radius: 4), prospectivePaint);

      // 候補点までの長さラベル
      var labelCenter = point2;
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${(distance * 100).toStringAsFixed(1)} cm',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      textPainter.layout();

      // 1-3点目は長さを下付き、4点目は上付きで表示
      if (points.length < 5) {
        labelCenter += Offset(0, textPainter.size.height + 10);
      } else {
        labelCenter -= Offset(0, textPainter.size.height + 10);
      }

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: labelCenter,
            width: textPainter.size.width + textPainter.size.height + 4,
            height: textPainter.size.height + 4,
          ),
          Radius.circular(textPainter.size.height / 2 + 2),
        ),
        prospectivePaint,
      );

      textPainter.paint(
        canvas,
        labelCenter - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }

    // // 天面
    if (topPoints.isNotEmpty || topVisiblePointIds.isNotEmpty) {
      for (var i = 1; i < topVisiblePointIds.length; i++) {
        final p0 = topPoints[topVisiblePointIds[i]];
        final p1 = topPoints[topVisiblePointIds[i - 1]];
        final p0Path = Path()..addOval(Rect.fromCircle(center: p0, radius: 4));
        final p1Path = Path()..addOval(Rect.fromCircle(center: p1, radius: 4));
        canvas.drawPath(p0Path, pointsPaint);
        canvas.drawPath(p1Path, pointsPaint);
        canvas.drawLine(p0, p1, pointsPaint);
      }
      if (topVisiblePointIds.length == 4) {
        final p0 = topPoints[topVisiblePointIds[0]];
        final p1 = topPoints[topVisiblePointIds[3]];
        canvas.drawLine(p0, p1, pointsPaint);
      }

      // 垂直線
      final verticalBarIds =
          topVisiblePointIds.length < bottomVisiblePointIds.length
              ? topVisiblePointIds
              : bottomVisiblePointIds;
      for (final i in verticalBarIds) {
        final p0 = topPoints[i];
        final p1 = points[i];
        canvas.drawLine(p0, p1, pointsPaint);

        if (i == pageController.arData.nearestPointId) {
          final height = pageController.arData.height!;
          final labelCenter = (p0 + p1) / 2;

          final textPainter = TextPainter(
            text: TextSpan(
              text: '${(height * 100).toStringAsFixed(1)} cm',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
          );
          textPainter.layout();

          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: labelCenter,
                width: textPainter.size.width + textPainter.size.height + 4,
                height: textPainter.size.height + 4,
              ),
              Radius.circular(textPainter.size.height / 2 + 2),
            ),
            linePaint,
          );
          textPainter.paint(
            canvas,
            labelCenter - Offset(textPainter.width / 2, textPainter.height / 2),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
