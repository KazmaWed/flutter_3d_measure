//
//  Untitled.swift
//  Runner
//
//  Created by Kazma Wed on 2025/11/14.
//

import Flutter
import UIKit
import ARKit
import RealityKit
import simd

class PlatformView: NSObject, FlutterPlatformView, ARSessionDelegate, ARSCNViewDelegate {
    let arView: ARView
    let channel: FlutterMethodChannel
    
    var cameraTransform:simd_float4x4?
    var viewMatrix:simd_float4x4?
    var firstCameraPosition: [Float] = []

    var center: simd_float3?
    var centerPosition: CGPoint?

    var bottomPoints: [simd_float3] = []
    var bottomPointsSerialized:[[Float]] = []
    var topPoints: [simd_float3] = []
    var topPointsSerialized : [[Float]] = []

    var prospectivePoint: simd_float3?

    var nearestPointId: Int?
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger
    ) {
        arView = ARView(
            frame: frame
        )
        channel = FlutterMethodChannel(
            name: "channel",
            binaryMessenger: messenger
        )
        super.init()
        
        arView.session.delegate = self
        channel.setMethodCallHandler(
            onMethodCalled
        )
        
        // ARViewの調整
        let configuration = ARWorldTrackingConfiguration()
        if ARWorldTrackingConfiguration.supportsFrameSemantics(
            .sceneDepth
        ) {
            configuration.frameSemantics = .sceneDepth
        } else {
            configuration.planeDetection = [.horizontal]
        }
        
        // For performance, disable all options.
        arView.environment.sceneUnderstanding.options = []
        arView.renderOptions = [
            .disableCameraGrain,
            .disableHDR,
            .disableGroundingShadows,
            .disableMotionBlur,
            .disableDepthOfField,
            .disableFaceMesh,
            .disablePersonOcclusion,
            .disableAREnvironmentLighting,
        ]
        
        arView.session.run(
            configuration
        )
    }
    
    func view() -> UIView {
        return arView
    }
    
    func onMethodCalled(
        _ call: FlutterMethodCall,
        _ result: @escaping FlutterResult
    ) {
        let arguments = call.arguments as? [String: Any]
        
        switch call.method {
        case "dispose":
            onDispose(result)
        case "allClear":
            allClear(result)
        case "savePoint":
            savePoint(result)
        case "undo":
            undo(result)
        case "snapshot":
            snapshot(arguments, result)
        default:
            result(
                FlutterMethodNotImplemented
            )
        }
    }
    
    func onDispose(
        _ result: FlutterResult
    ) {
        arView.session.pause()
        channel.setMethodCallHandler(
            nil
        )
        result(
            nil
        )
    }
    
    func allClear(
        _ result: FlutterResult
    ) {
        center = nil
        centerPosition = nil
        bottomPoints = []
        bottomPointsSerialized = []
        topPoints = []
        topPointsSerialized = []
        prospectivePoint = nil
        nearestPointId = nil
        result(
            nil
        )
    }
    
    func savePoint(
        _ result: FlutterResult
    ) {
        if let newPoint = _getProspectivePoint() {
            // 床面側の頂点を保存
            if bottomPoints.count < 4 {
                bottomPoints.append(
                    newPoint
                )
                bottomPointsSerialized.append(
                    newPoint.serialized()
                )
                
                // 3点目を決定すると自動的に4点目を決定、bottomPointsは必ず時計回りまたは反時計回りの並びにする
                if let fourthPoint = _getFourthPoint() {
                    if nearestPointId == 1 {
                        bottomPoints.append(
                            fourthPoint
                        )
                        bottomPointsSerialized.append(
                            fourthPoint.serialized()
                        )
                    } else {
                        bottomPoints.insert(
                            fourthPoint,
                            at: 2
                        );
                        bottomPointsSerialized.insert(
                            fourthPoint.serialized(),
                            at: 2
                        );
                    }
                }
            } else {
                // 天面側の頂点を保存
                let y = newPoint.y
                let top0 = simd_float3(
                    bottomPoints[0].x,
                    y,
                    bottomPoints[0].z
                )
                let top1 = simd_float3(
                    bottomPoints[1].x,
                    y,
                    bottomPoints[1].z
                )
                let top2 = simd_float3(
                    bottomPoints[2].x,
                    y,
                    bottomPoints[2].z
                )
                let top3 = simd_float3(
                    bottomPoints[3].x,
                    y,
                    bottomPoints[3].z
                )
                
                topPoints = [
                    top0,
                    top1,
                    top2,
                    top3
                ]
                topPointsSerialized = [
                    top0.serialized(),
                    top1.serialized(),
                    top2.serialized(),
                    top3.serialized()
                ]
            }
        }
        result(
            nil
        )
    }
    
    func undo(
        _ result: FlutterResult
    ) {
        if topPoints.count > 0 {
            topPoints = []
            topPointsSerialized = []
        } else {
            let count = bottomPoints.count == 4 ? 2 : bottomPoints.count > 0 ? 1 : 0
            for _ in 0..<count {
                bottomPoints.removeLast()
                bottomPointsSerialized.removeLast()
            }
        }
        result(
            nil
        )
    }

    func snapshot(_ arguments: [String: Any]?, _ result: FlutterResult) {
        guard let _savePath = arguments?["savePath"] as? String else {
            self.channel.invokeMethod("log", arguments: "Missing 'savePath' to call 'snapshot'")
            return result(nil)
        }
        // WARN: Xcodeデバッグでは、Product/Scheme/Edit SchemeでMetal API Validationを切ること
        // https://stackoverflow.com/questions/58085843/realitykit-arview-snapshot-fails
        arView.snapshot(saveToHDR: false) { image in
            let url = URL(fileURLWithPath: _savePath)
            do {
                if _savePath.hasSuffix("png") {
                try image!.pngData()!.write(to: url)
                } else {
                try image!.jpegData(compressionQuality: 0.85)!.write(to: url)
                }
            } catch {
                self.channel.invokeMethod("log", arguments: "An error occurred while saving the snapshot.")
            }
        }
        result(nil)
    }
    
    func session(
        _: ARSession,
        didUpdate frame: ARFrame
    ) {
        // 値の更新
        viewMatrix = frame.camera.viewMatrix(
            for: .portrait
        )
        cameraTransform = frame.camera.transform
        
        // 出力用値の初期化
        var bottomPointsPositions:[[Float]] = []
        var topPointsPositions: [[Float]] = []
        var prospectivePointSerialized:[Float] = []
        var prospectiveScreenPosition: [Float] = []
        
        // 底面の頂点のスクリーン座標取得（常に実行）
        for point in bottomPoints {
            if let screenPosition = arView.project(point) {
                bottomPointsPositions.append(
                    screenPosition.serialized()
                )
            }
        }
        // 天面の頂点のスクリーン座標取得（常に実行）
        for topPoint in topPoints {
            if let topPointPosition = arView.project(topPoint) {
                topPointsPositions.append(
                    topPointPosition.serialized()
                )
            }
        }

        switch frame.camera.trackingState {
        case .normal:
            // センターの更新
            if let newCenter = _hitTest() {
                center = newCenter
            } else {
                center = nil
                centerPosition = nil
            }

            // 次の候補点のワールド座標とスクリーン座標の取得
            if (
                center != nil && bottomPoints.count == 0
            ) || (
                1 <= bottomPoints.count && bottomPoints.count <= 4
            ) {
                prospectivePoint = _getProspectivePoint()
                if prospectivePoint != nil {
                    let prospectivePointProjected = arView.project(
                        prospectivePoint!
                    )!
                    prospectiveScreenPosition = prospectivePointProjected.serialized()
                    prospectivePointSerialized = prospectivePoint!.serialized()
                }
            }

        default:
            break
        }
        
        
        channel.invokeMethod(
            "didUpdateFrame",
            arguments: [
                "bottomPoints": bottomPointsSerialized,
                "bottomPointsPositions": bottomPointsPositions,
                "topPoints": topPointsSerialized,
                "topPointsPositions": topPointsPositions,
                "prospectivePoint": prospectivePointSerialized,
                "prospectiveScreenPosition": prospectiveScreenPosition,
                "cameraPosition": cameraTransform!.columns.3.serialized(),
                "firstCameraPosition": firstCameraPosition,
                "viewMatrix": viewMatrix!.transpose.serialized(),
                "allPointsAreInFront": _allPointsAreInFront(),
            ] as [String : Any?]
        )
    }
    
    /// 画面上の任意の座標を指定して、最も近い構造物の空間上の座標を取得する
    func _hitTest(
        point: CGPoint? = nil
    ) -> simd_float3? {
        let point = point ?? arView.center
        if let result = arView.hitTest(
            point
        ).first {
            return result.position
        }
        if let result = arView.raycast(
            from: point,
            allowing: .estimatedPlane,
            alignment: .any
        ).first {
            return .init(
                result.worldTransform.columns.3.x,
                result.worldTransform.columns.3.y,
                result.worldTransform.columns.3.z
            )
        }
        return nil
    }
    
    // 1点目を取得 (1点目 = 画面中央のhitTestの結果)
    func _getFirstPoint() -> simd_float3? {
        let cameraPosition = cameraTransform!.columns.3
        firstCameraPosition = [
            Float(
                cameraPosition.x
            ),
            Float(
                cameraPosition.y
            ),
            Float(
                cameraPosition.z
            )
        ]
        return center
    }
    
    // 2点目を取得 (2点目 = 1点目と同じy座標を持つ画面中心の点)
    func _getSecondPoint(
        max: Float = 1.7
    ) -> simd_float3? {
        if bottomPoints.count != 1 || viewMatrix == nil {
            return nil
        }
        
        let m11 = viewMatrix!.columns.0.x
        let m12 = viewMatrix!.columns.1.x
        let m13 = viewMatrix!.columns.2.x
        let m14 = viewMatrix!.columns.3.x
        let m21 = viewMatrix!.columns.0.y
        let m22 = viewMatrix!.columns.1.y
        let m23 = viewMatrix!.columns.2.y
        let m24 = viewMatrix!.columns.3.y
        let m31 = viewMatrix!.columns.0.z
        let m32 = viewMatrix!.columns.1.z
        let m33 = viewMatrix!.columns.2.z
        let m34 = viewMatrix!.columns.3.z
        let ay = bottomPoints[0].y
        
        let x = (
            (
                m12 * m23 - m22 * m13
            ) * ay + m14 * m23 - m24 * m13
        ) / (
            m21 * m13 - m11 * m23
        )
        let y = ay
        let z = -(
            m11 * x + m12 * ay + m14
        ) / m13
        let zDash = m31 * x + m32 * y + m33 * z + m34 // カメラ座標系のZ座標 (奥行き)
        
        // カメラより後ろの点は返さない
        if zDash >= 0 {
            return nil
        }
        
        var p0p1 = simd_float3(
            x,
            y,
            z
        ) - bottomPoints[0]
        let l = length(
            p0p1
        ) // 辺の長さ
        
        // 辺が最大値を超える場合は縮める
        if max < l {
            p0p1 = p0p1 / l * max
        }
        
        return bottomPoints[0] + p0p1
    }
    
    // 3点目を取得 (2点目を通り、1点目と 2点目を結ぶ直線に直行する直線上で、スクリーン上のx座標がゼロの点)
    func _getThirdPoint(
        max: Float = 1.7
    ) -> simd_float3? {
        if bottomPoints.count != 2 || viewMatrix == nil || cameraTransform == nil {
            return nil
        }
        
        // 最初の2点
        nearestPointId = _nearestPointId()
        let p0 = bottomPoints[nearestPointId!]
        let p1 = bottomPoints[1 - nearestPointId!]
        
        let m11 = viewMatrix!.columns.0.x
        let m12 = viewMatrix!.columns.1.x
        let m13 = viewMatrix!.columns.2.x
        let m14 = viewMatrix!.columns.3.x
        let m31 = viewMatrix!.columns.0.z
        let m32 = viewMatrix!.columns.1.z
        let m33 = viewMatrix!.columns.2.z
        let m34 = viewMatrix!.columns.3.z
        
        let ax = p0.x
        let ay = p0.y
        let az = p0.z
        let bx = p1.x
        let by = p1.y
        let bz = p1.z
        let A = (
            az - bz
        ) / (
            ax - bx
        )
        let y = ay
        var x = (
            m12 * ay + m13 * ax / A + m13 * az + m14
        ) / (
            m13 / A - m11
        )
        let z = -(
            x - ax
        ) / A + az
        let zDash = m31 * x + m32 * y + m33 * z + m34 // カメラ座標系のZ座標 (奥行き)
        
        // カメラより後ろの点は返さない
        if zDash >= 0 {
            return nil
        }
        
        // 最初に引いた直線より手前にカメラを向けた場合はゼロcmの点を返す
        if (
            z < A * (
                x - ax
            ) + az
        ) == (
            firstCameraPosition[2] < A * (
                firstCameraPosition[0] - ax
            ) + az
        ) {
            return p0
        }
        
        var p0p2 = simd_float3(
            x,
            y,
            z
        ) - p0
        let l = length(
            p0p2
        ) // 辺の長さ
        
        // 辺の長さが最大を超えないように補正
        if max < l {
            p0p2 = p0p2 / l * max
        }
        
        return p0 + p0p2
    }
    
    func _getFourthPoint() -> simd_float3? {
        if bottomPoints.count != 3 || viewMatrix == nil || nearestPointId == nil {
            return nil
        }
        
        let p0 = bottomPoints[1 - nearestPointId!]
        let p1 = bottomPoints[nearestPointId!]
        let p2 = bottomPoints[2]
        
        return p2 + p0 - p1
    }
    
    // 天面の頂点を取得 (3点目と同じx, z座標で、スクリーン上のy座標がゼロの点)
    func _getTopPoint(
        max: Float = 1.7
    ) -> simd_float3? {
        if cameraTransform == nil {
            return nil
        }
        
        let m21 = viewMatrix!.columns.0.y
        let m22 = viewMatrix!.columns.1.y
        let m23 = viewMatrix!.columns.2.y
        let m24 = viewMatrix!.columns.3.y
        let m31 = viewMatrix!.columns.0.z
        let m32 = viewMatrix!.columns.1.z
        let m33 = viewMatrix!.columns.2.z
        let m34 = viewMatrix!.columns.3.z
        let s = Float(
            sin(
                -Double.pi / 18
            )
        )
        let c = Float(
            cos(
                -Double.pi / 18
            )
        )
        
        nearestPointId = _nearestPointId()
        let x = bottomPoints[nearestPointId!].x
        let z = bottomPoints[nearestPointId!].z
        var y = (
            (
                m21 * c - m31 * s
            ) * x + (
                m23 * c - m33 * s
            ) * z + m24 * c - m34 * s
        ) / (
            m32 * s - m22 * c
        )
        
        let zDash = m31 * x + m32 * y + m33 * z + m34 // カメラ座標系のZ座標 (奥行き)
        
        // カメラより後ろの点は返さない
        if zDash >= 0 {
            return nil
        }
        
        // 高さが最大を超えないように補正
        if y < bottomPoints[2].y {
            y = bottomPoints[2].y
        } else if bottomPoints[2].y + max < y {
            y = bottomPoints[2].y + max
        }
        
        return simd_float3(
            x,
            y,
            z
        )
    }
    
    func _getProspectivePoint() -> simd_float3? {
        if bottomPoints.count == 0 {
            return _getFirstPoint()
        } else if bottomPoints.count == 1 {
            return _getSecondPoint()
        } else if bottomPoints.count == 2 {
            return _getThirdPoint()
        } else if bottomPoints.count == 4 && topPoints.count == 0 {
            return _getTopPoint()
        }
        return nil
    }
    
    // 角BACのcosを返す
    func _cosABC(
        pointA: simd_float3,
        pointB: simd_float3
    ) -> Float {
        let a = pointA.serialized()
        let b = pointB.serialized()
        let cameraPosition = cameraTransform!.columns.3
        let c = [
            Float(
                cameraPosition.x
            ),
            Float(
                cameraPosition.y
            ),
            Float(
                cameraPosition.z
            )
        ]
        
        let bax = a[0] - b[0]
        let baz = a[2] - b[2]
        let bcx = c[0] - b[0]
        let bcz = c[2] - b[2]
        
        let cosABC = (
            bax * bcx + baz * bcz
        ) / sqrt(
            bax * bax + baz * baz
        ) / sqrt(
            bcx * bcx + bcz * bcz
        )
        return cosABC
    }
    
    func _nearestPointId() -> Int? {
        if bottomPoints.count == 0 {
            return nil
        }
        
        let cameraPosition = cameraTransform!.columns.3
        let c = simd_float2(
            Float(
                cameraPosition.x
            ),
            Float(
                cameraPosition.z
            )
        )
        var d = distance(
            simd_float2(
                bottomPoints[0].x,
                bottomPoints[0].z
            ),
            c
        )
        var idx = 0
        
        if bottomPoints.count == 1 {
            return idx
        }
        
        for i in 1..<bottomPoints.count {
            let point = simd_float2(
                bottomPoints[i].x,
                bottomPoints[i].z
            )
            let newD = distance(
                point,
                c
            )
            if newD < d {
                d = newD
                idx = i
            }
        }
        
        return idx
    }
    
    func _allPointsAreInFront() -> Bool {
        let m31 = viewMatrix!.columns.0.z
        let m32 = viewMatrix!.columns.1.z
        let m33 = viewMatrix!.columns.2.z
        let m34 = viewMatrix!.columns.3.z
        
        for point in bottomPoints {
            let zDash = m31 * point.x + m32 * point.y + m33 * point.z + m34
            if zDash > 0 {
                return false
            }
        }
        for point in topPoints {
            let zDash = m31 * point.x + m32 * point.y + m33 * point.z + m34
            if zDash > 0 {
                return false
            }
        }
        
        return true;
    }
}


class PlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    
    init(
        messenger: FlutterBinaryMessenger
    ) {
        self.messenger = messenger
        super.init()
    }
    
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return PlatformView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger
        )
    }
    
    /// Implementing this method is only necessary when the `arguments` in `createWithFrame` is not `nil`.
    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

extension simd_float2 {
    func serialized() -> [Float] {
        return [
            x,
            y
        ]
    }
}

extension simd_float3 {
    func serialized() -> [Float] {
        return [
            x,
            y,
            z
        ]
    }
}

extension simd_float3x3 {
    func serialized() -> [[Float]] {
        return [
            columns.0.serialized(),
            columns.1.serialized(),
            columns.2.serialized(),
        ]
    }
}

extension simd_float4 {
    func serialized() -> [Float] {
        return [
            x,
            y,
            z,
            w
        ]
    }
}

extension simd_float4x4 {
    func serialized() -> [[Float]] {
        return [
            columns.0.serialized(),
            columns.1.serialized(),
            columns.2.serialized(),
            columns.3.serialized(),
        ]
    }
}

extension CGPoint {
    func serialized() -> [Float] {
        return [
            Float(
                x
            ),
            Float(
                y
            )
        ]
  }
}
