import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vector_math/vector_math_64.dart';

import '../models/no_lidar_ardata.dart';
// import 'platform_view_page_controller_extension.dart';

class PlatformViewPageController {
  final Function onUpdateFrame;
  final bool gemini;
  final bool logging;
  late MethodChannel channel;
  late BuildContext context;

  PlatformViewPageController.init({
    required this.context,
    required this.onUpdateFrame,
    this.gemini = false,
    this.logging = false,
  }) {
    channel = const OptionalMethodChannel('channel');
    channel.setMethodCallHandler(_platformCallHandler);
    initDeviceInfo();
  }

  // デバグ情報表示切り替え
  bool showDebugInfo = false;
  // swiftから受け取るデータクラス
  var arData = NoLidarARData();
  var geminiResponce = '';

  // 候補点がない時のクルクル表示
  bool get shouldShowCircularIndicator =>
      arData.prospectivePoint == null && arData.topPoints.isEmpty;
  // ペインターを表示するかどうか
  bool get shouldShowPainter => true;
  // 真正面から撮影時の「横から撮影してください」警告フラグ
  bool get shouldMoveSideways => arData.shouldMoveSideways;
  // 近づき過ぎて撮影時の「離れて撮影してください」警告フラグ
  bool get shouldMoveBackward => arData.shouldMoveBackward;
  // 計測の進捗度
  NoLidarARDataShootingState get state {
    if (arData.bottomPoints.isEmpty &&
        arData.bottomPointsPositions.isEmpty &&
        arData.topPoints.isEmpty &&
        arData.topPointsPositions.isEmpty) {
      return NoLidarARDataShootingState.shootingFirst;
    } else if (arData.bottomPoints.length == 1 &&
        arData.bottomPointsPositions.length == 1 &&
        arData.topPoints.isEmpty &&
        arData.topPointsPositions.isEmpty) {
      return NoLidarARDataShootingState.shootingSecond;
    } else if (arData.bottomPoints.length == 2 &&
        arData.bottomPointsPositions.length == 2 &&
        arData.topPoints.isEmpty &&
        arData.topPointsPositions.isEmpty) {
      return NoLidarARDataShootingState.shootingThird;
    } else if (arData.bottomPoints.length == 4 &&
        arData.bottomPointsPositions.length == 4 &&
        arData.topPoints.isEmpty &&
        arData.topPointsPositions.isEmpty) {
      return NoLidarARDataShootingState.shootingHeight;
    } else if (arData.bottomPoints.length == 4 &&
        arData.bottomPointsPositions.length == 4 &&
        arData.topPoints.length == 4 &&
        arData.topPointsPositions.length == 4) {
      return NoLidarARDataShootingState.done;
    } else {
      return NoLidarARDataShootingState.undifined;
    }
  }

  // デバグ表示切り替え
  void toggleShowDebug() {
    showDebugInfo = !showDebugInfo;
  }

  // Swiftから実行するメソッド類
  Future<void> _platformCallHandler(MethodCall call) {
    try {
      switch (call.method) {
        case 'log':
          _logHandler(call);
          break;
        case 'didUpdateFrame':
          _didUpdateFrameHandler(call);
          break;
        default:
          debugPrint(call.arguments);
      }
    } on Exception catch (e) {
      debugPrint(e.toString());
    }
    return Future.value();
  }

  // デバイス情報取得
  void initDeviceInfo() async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    await deviceInfo.iosInfo.then((iosInfo) {
      uniqueId = iosInfo.identifierForVendor ?? 'unknown';
      productName = iosInfo.utsname.machine;
      iosVersion = iosInfo.systemVersion;
    });
    PackageInfo.fromPlatform().then((packageInfo) {
      appVersion = packageInfo.version;
    });
  }

  // カメラ位置履歴更新
  void updateShootingHistory() {
    if (arData.cameraPosition != null) {
      if (state == NoLidarARDataShootingState.shootingFirst) {
        if (shootingTimestamp.isEmpty) {
          shootingTimestamp.add(DateTime.now().toIso8601String());
        }
        if (cameraPositionHistory.isNotEmpty) {
          cameraPositionHistory = [];
          shootingTimestamp = [shootingTimestamp[0]];
        }
      } else if (state == NoLidarARDataShootingState.shootingSecond) {
        if (cameraPositionHistory.isEmpty || cameraPositionHistory.length >= 2) {
          cameraPositionHistory = [arData.cameraPosition!];
          shootingTimestamp = [shootingTimestamp[0], DateTime.now().toIso8601String()];
        }
      } else if (state == NoLidarARDataShootingState.shootingThird) {
        if (cameraPositionHistory.length == 1 || cameraPositionHistory.length >= 2) {
          cameraPositionHistory = [cameraPositionHistory[0], arData.cameraPosition!];
          shootingTimestamp = [
            shootingTimestamp[0],
            shootingTimestamp[1],
            DateTime.now().toIso8601String(),
          ];
        }
      } else if (state == NoLidarARDataShootingState.shootingHeight) {
        if (cameraPositionHistory.length == 2) {
          cameraPositionHistory = [
            cameraPositionHistory[0],
            cameraPositionHistory[1],
            arData.cameraPosition!,
          ];
          shootingTimestamp = [
            shootingTimestamp[0],
            shootingTimestamp[1],
            shootingTimestamp[2],
            DateTime.now().toIso8601String(),
          ];
        }
      } else if (state == NoLidarARDataShootingState.done) {
        if (cameraPositionHistory.length == 3) {
          cameraPositionHistory = [
            cameraPositionHistory[0],
            cameraPositionHistory[1],
            cameraPositionHistory[2],
            arData.cameraPosition!,
          ];
          shootingTimestamp = [
            shootingTimestamp[0],
            shootingTimestamp[1],
            shootingTimestamp[2],
            shootingTimestamp[3],
            DateTime.now().toIso8601String(),
          ];

          // ---------- ログ保存 ----------
          // final dateTime = DateTime.now();
          // // カメラ画像
          // if (logging || gemini) {
          //   _getSnapshot().then((file) {
          //     if (file != null) {
          //       if (gemini) _gemini(file);
          //       if (logging) _uploadImageFile(file: file, dateTime: dateTime);
          //     }
          //   });
          // }
          // // ペインター画像
          // _getImageFileFromKey().then((file) {
          //   if (file != null) _uploadImageFile(file: file, dateTime: dateTime);
          // });
        }
      }
    }
  }

  /// フレーム更新
  Future<void> _didUpdateFrameHandler(MethodCall call) async {
    // ARデータ取得
    final arguments = call.arguments as Map<dynamic, dynamic>;
    arData = NoLidarARData.fromArguments(arguments);

    print(
      {
        "topPoints": arData.topPoints.length,
        "bottomPoints": arData.bottomPoints.length,
        "cameraPosition": [
          arData.cameraPosition?.x.toStringAsFixed(2),
          arData.cameraPosition?.y.toStringAsFixed(2),
          arData.cameraPosition?.z.toStringAsFixed(2),
        ].toString(),
      }.toString(),
    );

    updateShootingHistory(); // ログ用
    onUpdateFrame();
  }

  /// Swiftからのログ受け取り
  Future<void> _logHandler(MethodCall call) async {
    final arguments = call.arguments as Map<dynamic, dynamic>;
    debugPrint(arguments.toString());
  }

  /// 頂点の追加
  Future<void> savePoint() async {
    await channel.invokeMethod('savePoint');
  }

  /// 頂点の初期化
  void allClear() {
    cameraPositionHistory = []; // ログ用
    shootingTimestamp = [];
    geminiResponce = '';
    channel.invokeMethod('allClear');
  }

  /// ひとつ戻る
  void undo() {
    cameraPositionHistory.removeLast();
    if (cameraPositionHistory.isEmpty) shootingTimestamp = [];

    channel.invokeMethod('undo');
  }

  /// 計測中の辺の長さ
  double? get distanceToProspective {
    if (arData.bottomPoints.isEmpty || arData.prospectivePoint == null) {
      return null;
    }
    if (arData.bottomPoints.length < 4) {
      return arData.bottomPoints.last.distanceTo(arData.prospectivePoint!);
    } else if (arData.nearestBottomPoint != null) {
      return arData.nearestBottomPoint!.distanceTo(arData.prospectivePoint!);
    } else {
      return null;
    }
  }

  // ---------- 以下ログ用 ----------
  // ログ用メソッドは`lib/pages/platform_view_page_controller_extension.dart`に記載

  var globalKey = GlobalKey();
  var cameraPositionHistory = <Vector3>[]; // 計測時のカメラ位置
  var shootingTimestamp = <String>[];
  var uniqueId = 'unknown'; // UUID
  var productName = 'unknown'; // デバイス名
  var iosVersion = 'unknown'; // iOSバージョン
  var appVersion = 'unknown'; // アプリバージョン
}

// 計測の進捗度クラス
enum NoLidarARDataShootingState {
  shootingFirst,
  shootingSecond,
  shootingThird,
  shootingHeight,
  done,
  undifined,
}
