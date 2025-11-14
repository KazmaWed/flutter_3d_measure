import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart';

class Utilities {
  static Vector3? argumentsToVector3(List<dynamic>? list) {
    if (list == null || list.isEmpty) return null;
    final x = list[0] as double;
    final y = list[1] as double;
    final z = list[2] as double;
    return Vector3.array([x, y, z]);
  }

  static Offset? argumentsToOffset(List<dynamic>? list) {
    if (list == null || list.isEmpty) return null;
    final x = list[0] as double;
    final y = list[1] as double;
    return Offset(x, y);
  }

  static List<Vector3> argumentsToVectorList(List<dynamic>? list) {
    if (list == null || list.isEmpty || list[0].length < 3) return [];
    return list.map((e) => Vector3(e[0], e[1], e[2])).toList(growable: false);
  }

  static List<Offset> argumentsToOffsetList(List<dynamic>? list) {
    if (list == null || list.isEmpty || list[0].length < 2) return [];
    return list.map((e) => Offset(e[0], e[1])).toList(growable: false);
  }

  static Matrix4? argumentsToMatrix4(List<dynamic>? list) {
    if (list == null || list.length <= 4 || list.first.length <= 4) return null;

    List<double> values = [];
    for (var i = 0; i < 4; i++) {
      for (var j = 0; j < 4; j++) {
        values.add(list[i][j] as double);
      }
    }
    return Matrix4.fromList(values);
  }

  // ログ用
  static Future<String> get cameraViewImageFilePath async {
    final tempDirPath = (await getTemporaryDirectory()).path;
    final filePath = '$tempDirPath/3d_measure_camera.jpeg';
    return filePath;
  }

  static Future<String> get painterImageFilePath async {
    final tempDirPath = (await getTemporaryDirectory()).path;
    final filePath = '$tempDirPath/3d_measure_painter.png';
    return filePath;
  }
}

extension Vector3Extension on Vector3 {
  String toStringAsFixed(int i) {
    return 'Vector3(x: ${x.toStringAsFixed(i)}, y: ${y.toStringAsFixed(i)}, z: ${z.toStringAsFixed(i)})';
  }
}

extension Vector3ListExtension on List<Vector3> {
  String toStringAsFixed(int i) {
    return map((e) => e.toStringAsFixed(i)).toList().toString();
  }
}
