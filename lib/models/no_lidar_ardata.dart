import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

import '../utilities.dart';

class NoLidarARData {
  Vector3? prospectivePoint;
  Offset? prospectiveScreenPosition;
  Matrix4? cameraTransform;
  Matrix4? viewMatrix;
  Vector3? cameraPosition;
  Vector3? firstCameraPosition;
  List<Vector3> bottomPoints = [];
  List<Offset> bottomPointsPositions = [];
  List<Vector3> topPoints = [];
  List<Offset> topPointsPositions = [];
  bool allPointsAreInFront = true;

  NoLidarARData();

  NoLidarARData.fromArguments(Map<dynamic, dynamic> arguments) {
    // 頂点
    bottomPoints = Utilities.argumentsToVectorList(arguments['bottomPoints']);
    bottomPointsPositions =
        Utilities.argumentsToOffsetList(arguments['bottomPointsPositions']);
    topPoints = Utilities.argumentsToVectorList(arguments['topPoints']);
    topPointsPositions =
        Utilities.argumentsToOffsetList(arguments['topPointsPositions']);

    // 次候補の点
    prospectivePoint =
        Utilities.argumentsToVector3(arguments['prospectivePoint']);
    prospectiveScreenPosition =
        Utilities.argumentsToOffset(arguments['prospectiveScreenPosition']);

    // カメラ
    cameraPosition = Utilities.argumentsToVector3(arguments['cameraPosition']);
    viewMatrix = Utilities.argumentsToMatrix4(arguments['viewMatrix']);
    firstCameraPosition =
        Utilities.argumentsToVector3(arguments['firstCameraPosition']);
    allPointsAreInFront = arguments['allPointsAreInFront'];
  }

  List<double> get distances {
    final output = <double>[];
    if (bottomPoints.length < 2) return [];
    for (var i = 0; i < bottomPoints.length; i++) {
      final d = bottomPoints[i]
          .distanceTo(bottomPoints[(i + 1) % bottomPoints.length]);
      output.add(d);
    }
    return output;
  }

  double? get height {
    if (bottomPoints.isEmpty || topPoints.isEmpty) return null;
    return bottomPoints[0].distanceTo(topPoints[0]);
  }

  int? get nearestPointId => _nearestPointId();
  Vector3? get nearestBottomPoint {
    if (bottomPoints.isEmpty || nearestPointId == null) {
      return null;
    } else {
      return bottomPoints[nearestPointId!];
    }
  }

  Vector3 get size {
    if (bottomPoints.length < 2 || height == null) return Vector3.zero();
    return Vector3(
      bottomPoints[0].distanceTo(bottomPoints[1]),
      height!,
      bottomPoints[2].distanceTo(bottomPoints[1]),
    );
  }

  List<int> get bottomVisiblePointIds => _bottomVisiblePointIds();
  List<int> get topVisiblePointIds => _topVisiblePointIds();
  bool get shouldMoveSideways => _shouldMoveSideways();
  bool get shouldMoveBackward => !allPointsAreInFront;
  bool get inSameSideAsFirstShot => _inSameSideAsFirstShot();

  // bottomPointsのうちカメラから最も近い頂点のindex
  int? _nearestPointId() {
    if (bottomPoints.isEmpty || cameraPosition == null) return null;
    if (bottomPoints.length == 1) return 0;

    var pointId = 0;
    var minDistance = bottomPoints[0].distanceTo(cameraPosition!);

    for (var i = 1; i < bottomPoints.length; i++) {
      final newDistance = bottomPoints[i].distanceTo(cameraPosition!);
      if (newDistance < minDistance) {
        pointId = i;
        minDistance = newDistance;
      }
    }

    return pointId;
  }

  // 3点目決定時に、不正な方向 (辺の正面または左右30度以内) から撮影してるかどうかチェック
  bool _shouldMoveSideways() {
    if (cameraPosition == null || bottomPoints.length != 2) return false;

    final p0 = bottomPoints[0];
    final p1 = bottomPoints[1];
    final c = cameraPosition!;
    const threshold = -0.5;

    final cosCP0P1 = _horizontalCosABC(c, p0, p1);
    final cosCP1P0 = _horizontalCosABC(c, p1, p0);

    return threshold < cosCP0P1 &&
        threshold < cosCP1P0 &&
        _inSameSideAsFirstShot();
  }

  // 2点目を決定時、デバイスが辺を挟んで同じ側にいるかどうか、_shouldMoveSideways()内で使用
  bool _inSameSideAsFirstShot() {
    if (bottomPoints.length != 2 ||
        firstCameraPosition == null ||
        cameraPosition == null) return false;
    final p0 = bottomPoints[0];
    final p1 = bottomPoints[1];
    final angle = (p0.z - p1.z) / (p0.x - p1.x);
    return cameraPosition!.z < angle * (cameraPosition!.x - p0.x) + p0.z ==
        firstCameraPosition!.z < angle * (firstCameraPosition!.x - p0.x) + p0.z;
  }

  List<int> _bottomVisiblePointIds() {
    if (bottomPoints.isEmpty || cameraPosition == null) return [];
    if (bottomPoints.length == 1) return [0];
    if (bottomPoints.length == 2) return [0, 1];

    final near = _nearestPointId()!;
    if (cameraPosition!.y < bottomPoints.first.y) {
      return [(near - 1) % 4, near, (near + 1) % 4, (near + 2) % 4];
    }
    var candidates = [(near - 1) % 4, near, (near + 1) % 4];

    const threshold = 0;
    final cosCP1P0 = _horizontalCosABC(
      cameraPosition!,
      bottomPoints[candidates[1]],
      bottomPoints[candidates[0]],
    );
    final cosCP1P2 = _horizontalCosABC(
      cameraPosition!,
      bottomPoints[candidates[1]],
      bottomPoints[candidates[2]],
    );

    if (threshold < cosCP1P0) {
      candidates.removeAt(2);
    } else if (threshold < cosCP1P2) {
      candidates.removeAt(0);
    }

    return candidates;
  }

  List<int> _topVisiblePointIds() {
    if (topPoints.isEmpty || cameraPosition == null) return [];
    final near = _nearestPointId()!;
    if (topPoints.first.y < cameraPosition!.y) {
      return [(near - 1) % 4, near, (near + 1) % 4, (near + 2) % 4];
    }
    var candidates = [(near - 1) % 4, near, (near + 1) % 4];

    const threshold = 0;
    final cosCP1P0 = _horizontalCosABC(
      cameraPosition!,
      bottomPoints[candidates[1]],
      bottomPoints[candidates[0]],
    );
    final cosCP1P2 = _horizontalCosABC(
      cameraPosition!,
      bottomPoints[candidates[1]],
      bottomPoints[candidates[2]],
    );

    if (threshold < cosCP1P0) {
      candidates.removeAt(2);
    } else if (threshold < cosCP1P2) {
      candidates.removeAt(0);
    }

    return candidates;
  }

  double _cosABC(Vector3 a, Vector3 b, Vector3 c) {
    final ba = a - b;
    final bc = c - b;

    final cosABC =
        (ba.x * bc.x + ba.y * bc.y + ba.z * bc.z) / ba.length / bc.length;
    return cosABC;
  }

  double _horizontalCosABC(Vector3 a, Vector3 b, Vector3 c) {
    return _cosABC(
      Vector3(a.x, 0, a.z),
      Vector3(b.x, 0, b.z),
      Vector3(c.x, 0, c.z),
    );
  }
}
