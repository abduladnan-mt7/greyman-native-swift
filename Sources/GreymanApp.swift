// GreymanApp.swift
// Greyman Executive — Pure Native Swift / SwiftUI
// Entry point with full AVAudioSession background + APNs + Dynamic Island

import SwiftUI
import AVFoundation
import MediaPlayer
import UserNotifications

@main
struct GreymanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var audioEngine = AudioEngine.shared
    @StateObject private var wsManager = WebSocketManager.shared
    @StateObject private var permissionsManager = PermissionsManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(audioEngine)
                .environmentObject(wsManager)
                .environmentObject(permissionsManager)
                .preferredColorScheme(.dark)
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ app: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // 1. Activate background audio session
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP, .allowAirPlay])
            try session.setActive(true)
        } catch { print("AVAudioSession error: \(error)") }

        // 2. Lock screen media controls
        UIApplication.shared.beginReceivingRemoteControlEvents()

        // 3. Push notifications
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert]) { granted, _ in
            if granted { DispatchQueue.main.async { app.registerForRemoteNotifications() } }
        }

        // 4. Start WebSocket connection to Greyman server
        WebSocketManager.shared.connect()

        return true
    }

    func application(_ app: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        let tokenStr = token.map { String(format: "%02x", $0) }.joined()
        print("APNs Device Token: \(tokenStr)")
        WebSocketManager.shared.sendDeviceToken(tokenStr)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound, .badge])
    }
}
