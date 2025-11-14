import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    weak var registrar = self.registrar(forPlugin: "plugin-name")

    let factory = PlatformViewFactory(messenger: registrar!.messenger())
    self.registrar(forPlugin: "<plugin-name>")!.register(
      factory,
      withId: "platform-view")
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
