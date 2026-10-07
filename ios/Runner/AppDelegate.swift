import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    migrateLegacyDefaults()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  /// 옛 Swift 앱(같은 번들 ID)에서 업데이트한 사용자 — UserDefaults 값 중 shared_preferences가
  /// 읽지 못하는 타입(Data·Date·Dictionary)을 Flutter가 읽는 키로 한 번 변환해 둔다.
  /// 나머지(Int·Bool·String·[String])는 같은 키 그대로 Flutter(prefix '')가 읽는다.
  private func migrateLegacyDefaults() {
    let d = UserDefaults.standard
    let flag = "migration.legacyConverted.v1"
    guard !d.bool(forKey: flag) else { return }
    // Codable JSON(Data) → 문자열
    for (from, to) in [("ranking.localRecords", "ranking.localRecords.json"),
                       ("solo.resume.snapshot", "solo.resume.snapshot.json")] {
      if let data = d.data(forKey: from), let s = String(data: data, encoding: .utf8) {
        d.set(s, forKey: to)
      }
    }
    // Date → epoch ms
    if let date = d.object(forKey: "notice.lastSeenDate") as? Date {
      d.set(Int(date.timeIntervalSince1970 * 1000), forKey: "notice.lastSeenMs")
    }
    // [String: Int] → JSON 문자열
    if let dict = d.dictionary(forKey: "daily.progress"),
       let data = try? JSONSerialization.data(withJSONObject: dict),
       let s = String(data: data, encoding: .utf8) {
      d.set(s, forKey: "daily.progress.json")
    }
    d.set(true, forKey: flag)
  }
}
