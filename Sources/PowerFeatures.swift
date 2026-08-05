// PowerFeatures.swift
// Insanely powerful native iOS features built into Greyman Executive

import Foundation
import CoreLocation
import HealthKit
import LocalAuthentication
import CoreNFC
import BackgroundTasks
import UserNotifications
import AVFoundation
import Contacts

// MARK: - 1. FACE ID / TOUCH ID BIOMETRIC LOCK
class BiometricLock: ObservableObject {
    @Published var isUnlocked = false
    @Published var lockReason = ""

    func authenticate(reason: String = "Verify identity to access Greyman Executive", completion: @escaping (Bool) -> Void) {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    self.isUnlocked = success
                    completion(success)
                }
            }
        } else {
            // Fallback to passcode
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    self.isUnlocked = success
                    completion(success)
                }
            }
        }
    }
}

// MARK: - 2. GEOFENCE AUTOMATION ENGINE
// Auto-triggers: arrive home → start audio, leave home → pause
class GeofenceEngine: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = GeofenceEngine()
    @Published var currentLocation = ""
    @Published var isHome = false
    @Published var geofenceStatus = "Monitoring..."

    private let locationManager = CLLocationManager()
    private var homeRegion: CLCircularRegion?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
    }

    func setup(homeLat: Double, homeLon: Double, radius: Double = 150) {
        locationManager.requestAlwaysAuthorization()
        let center = CLLocationCoordinate2D(latitude: homeLat, longitude: homeLon)
        homeRegion = CLCircularRegion(center: center, radius: radius, identifier: "GreymanHome")
        homeRegion?.notifyOnEntry = true
        homeRegion?.notifyOnExit = true
        if let region = homeRegion {
            locationManager.startMonitoring(for: region)
        }
        locationManager.startUpdatingLocation()
        geofenceStatus = "Geofence active — Home zone: \(radius)m radius"
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        if region.identifier == "GreymanHome" {
            isHome = true
            geofenceStatus = "🏠 Arrived home — auto-starting stream"
            AudioEngine.shared.play()
            sendGeofenceAlert(title: "Welcome Home, Boss!", body: "Greyman audio stream auto-started.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        if region.identifier == "GreymanHome" {
            isHome = false
            geofenceStatus = "🚶 Left home zone"
            AudioEngine.shared.pause()
            sendGeofenceAlert(title: "Left Home Zone", body: "Greyman stream paused automatically.")
        }
    }

    private func sendGeofenceAlert(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}

// MARK: - 3. HEALTHKIT STRESS & SLEEP MONITOR
class HealthMonitor: ObservableObject {
    static let shared = HealthMonitor()
    @Published var heartRate: Double = 0
    @Published var sleepHours: Double = 0
    @Published var stressLevel = "Unknown"

    private let healthStore = HKHealthStore()

    func requestPermissions() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!
        ]
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { _, _ in
            self.fetchHeartRate()
            self.fetchSleepData()
        }
    }

    func fetchHeartRate() {
        guard let type = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
        let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]) { _, samples, _ in
            if let sample = samples?.first as? HKQuantitySample {
                DispatchQueue.main.async {
                    self.heartRate = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    self.stressLevel = self.heartRate > 100 ? "⚠️ High" : self.heartRate > 75 ? "🟡 Moderate" : "🟢 Calm"
                }
            }
        }
        healthStore.execute(query)
    }

    func fetchSleepData() {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: Date())
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 50, sortDescriptors: nil) { _, samples, _ in
            let total = samples?.compactMap { $0 as? HKCategorySample }
                .filter { $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue }
                .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) } ?? 0
            DispatchQueue.main.async {
                self.sleepHours = total / 3600
            }
        }
        healthStore.execute(query)
    }
}

// MARK: - 4. BACKGROUND FETCH ENGINE
// Pulls new audio/commands from Greyman server every 15 minutes in background
class BackgroundFetchEngine {
    static let shared = BackgroundFetchEngine()
    let taskIdentifier = "control.anticode.greyman.executive.backgroundfetch"

    func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            self.handleBackgroundFetch(task: task as! BGAppRefreshTask)
        }
    }

    func scheduleNext() {
        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleBackgroundFetch(task: BGAppRefreshTask) {
        scheduleNext()
        // Fetch latest audio update from server
        let url = URL(string: "https://whenever-mods-homework-logan.trycloudflare.com/radio.mp3")!
        let fetchTask = URLSession.shared.dataTask(with: url) { data, response, _ in
            if let data = data, !data.isEmpty {
                // New audio available — update buffer and notify
                let content = UNMutableNotificationContent()
                content.title = "🎙️ Greyman Update"
                content.body = "New voice update available. Tap to listen."
                content.sound = .default
                let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                UNUserNotificationCenter.current().add(req)
            }
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = { fetchTask.cancel() }
        fetchTask.resume()
    }
}

// MARK: - 5. SIRI SHORTCUTS INTEGRATION
import Intents

class SiriShortcutsManager {
    static func donateStartStreamShortcut() {
        let activity = NSUserActivity(activityType: "control.anticode.greyman.executive.startstream")
        activity.title = "Start Greyman Stream"
        activity.isEligibleForSearch = true
        activity.isEligibleForPrediction = true
        activity.suggestedInvocationPhrase = "Hey Greyman"
        activity.becomeCurrent()
    }
}

// MARK: - 6. CONTACT DIALER — Boss's VIP contact quick-dial
class QuickDialer: ObservableObject {
    func callNumber(_ number: String) {
        guard let url = URL(string: "tel://\(number.filter { $0.isNumber })") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - 7. CRASH RECOVERY — Auto-restart audio on app foreground
class CrashRecovery {
    static func setupForegroundAudioRestore() {
        NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            if AudioEngine.shared.isPlaying {
                AudioEngine.shared.play()
            }
        }
    }
}
