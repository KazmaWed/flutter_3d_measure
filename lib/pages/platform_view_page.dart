import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'platform_view_page_controller.dart';
import '../components/ar_painter.dart';
// import '../utilities.dart';

class PlatformViewPage extends StatefulWidget {
  const PlatformViewPage({super.key});

  @override
  State<PlatformViewPage> createState() => _PlatformViewPageState();
}

class _PlatformViewPageState extends State<PlatformViewPage> {
  late final PlatformViewPageController pageController;

  @override
  void initState() {
    super.initState();
    pageController = PlatformViewPageController.init(
      context: context,
      onUpdateFrame: () => setState(() {}),
    );
  }

  Widget _directionMessageContainer(String message, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          alignment: Alignment.topCenter,
          child: Card(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12.0),
                  alignment: Alignment.center,
                  child: Text(
                    message,
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _directionMessage() {
    if (pageController.shouldMoveBackward) {
      return _directionMessageContainer(
        '計測対象を正面に写してください',
        Theme.of(context).colorScheme.error,
      );
    } else if (pageController.shouldMoveSideways) {
      return _directionMessageContainer(
        '箱の左右の面を写してください',
        Theme.of(context).colorScheme.error,
      );
    } else if (pageController.state ==
            NoLidarARDataShootingState.shootingFirst ||
        pageController.state == NoLidarARDataShootingState.shootingSecond) {
      return _directionMessageContainer(
        '底面の頂点にカメラを合わせて\nシャッターボタンを押してください',
        Theme.of(context).colorScheme.primary,
      );
    } else if (pageController.state ==
        NoLidarARDataShootingState.shootingThird) {
      return _directionMessageContainer(
        '底面の辺と重なるように線を合わせて\nシャッターボタンを押してください',
        Theme.of(context).colorScheme.primary,
      );
    } else if (pageController.state ==
        NoLidarARDataShootingState.shootingHeight) {
      return _directionMessageContainer(
        '高さが合うように線を伸ばして\nシャッターボタンを押してください',
        Theme.of(context).colorScheme.primary,
      );
    } else if (pageController.state == NoLidarARDataShootingState.done) {
      return _directionMessageContainer(
        '計測完了',
        Theme.of(context).colorScheme.primary,
      );
    } else {
      return Container();
    }
  }

  Widget _debugInfoWindow() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white54,
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(pageController.geminiResponce),
                  ),
                ]),
                // Row(children: [
                //   Expanded(
                //     child: Text(
                //         'prospective point: ${pageController.arData.prospectivePoint?.toStringAsFixed(3)}'),
                //   ),
                // ]),
                // Row(children: [
                //   Expanded(
                //     child: Text('points:\n'
                //         '${pageController.arData.bottomPoints.toStringAsFixed(3)}'),
                //   ),
                // ]),
                // Row(children: [
                //   Expanded(
                //     child: Text(
                //         'camera position: ${pageController.arData.cameraPosition?.toStringAsFixed(3)}'),
                //   ),
                // ]),
                // Row(children: [
                //   Expanded(
                //     child: Text(
                //         'camera position history:\n${pageController.cameraPositionHistory.toStringAsFixed(3)}'),
                //   ),
                // ]),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> creationParams = <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(
        title: const Text('三辺計測メジャー'),
        actions: [
          IconButton(
            onPressed: pageController.toggleShowDebug,
            icon: const Icon(Icons.info_rounded),
          )
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          UiKitView(
            viewType: 'platform-view',
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
          ),
          if (pageController.shouldShowPainter)
            RepaintBoundary(
              key: pageController.globalKey,
              child: CustomPaint(
                painter: ARPainter(pageController: pageController),
              ),
            ),
          if (pageController.shouldShowCircularIndicator)
            const Center(child: CircularProgressIndicator()),
          _directionMessage(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (pageController.showDebugInfo) _debugInfoWindow(),
                  const SizedBox(width: 8),
                  Row(children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: pageController.arData.bottomPoints.isEmpty
                            ? null
                            : () => pageController.allClear(),
                        child: const Text('クリア'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: pageController.arData.bottomPoints.isEmpty
                            ? null
                            : () => pageController.undo(),
                        child: const Text('ひとつ戻る'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            pageController.arData.prospectivePoint == null
                                ? null
                                : () => pageController.savePoint(),
                        child: const Text('シャッターボタン'),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
