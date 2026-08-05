// WebSocketManager.swift
// Real-time WebSocket connection to Greyman server
// Receives commands, audio updates, push payloads from Greyman AI

import Foundation
import Combine
import UserNotifications
import UIKit

class WebSocketManager: NSObject, ObservableObject, URLSessionWebSocketDelegate {
    static let shared = WebSocketManager()

    @Published var isConnected = false
    @Published var lastCommand = ""
    @Published var serverMessages: [ServerMessage] = []

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var reconnectTimer: Timer?
    private var deviceToken: String = ""

    let wsURL = "wss://editorials-vsnet-distance-replica.trycloudflare.com"

    struct ServerMessage: Identifiable {
        let id = UUID()
        let text: String
        let type: MessageType
        let timestamp: Date

        enum MessageType { case audio, command, notification, info }
    }

    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    }

    func connect() {
        guard let url = URL(string: wsURL) else { return }
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
        receiveLoop()
        scheduleHeartbeat()
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        isConnected = false
    }

    func sendDeviceToken(_ token: String) {
        deviceToken = token
        let payload = ["type": "register", "device_token": token, "platform": "ios"]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let str = String(data: data, encoding: .utf8) {
            send(text: str)
        }
    }

    func send(text: String) {
        webSocketTask?.send(.string(text)) { _ in }
    }

    private func receiveLoop() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .string(let text): self.handleMessage(text)
                case .data(let data):
                    // Binary audio data - pipe to AudioEngine
                    self.handleAudioData(data)
                @unknown default: break
                }
                self.receiveLoop()
            case .failure:
                self.isConnected = false
                self.scheduleReconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let msg = ServerMessage(text: text, type: .info, timestamp: Date())
            serverMessages.insert(msg, at: 0)
            if serverMessages.count > 50 { serverMessages.removeLast() }
            return
        }

        let type = json["type"] as? String ?? "info"
        let content = json["content"] as? String ?? text

        switch type {
        case "audio_update":
            lastCommand = "🎙️ New audio update incoming..."
            if let url = json["url"] as? String, let _ = URL(string: url) {
                AudioEngine.shared.play()
            }
        case "command":
            lastCommand = content
            serverMessages.insert(ServerMessage(text: "⚡ \(content)", type: .command, timestamp: Date()), at: 0)
        case "notification":
            sendLocalNotification(title: json["title"] as? String ?? "Greyman", body: content)
        default:
            serverMessages.insert(ServerMessage(text: content, type: .info, timestamp: Date()), at: 0)
        }
        if serverMessages.count > 50 { serverMessages.removeLast() }
    }

    private func handleAudioData(_ data: Data) {
        // Write binary audio chunk to temp file and play
        let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("greyman_live.mp3")
        try? data.write(to: tmpURL)
        AudioEngine.shared.play()
    }

    private func sendLocalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    private func scheduleHeartbeat() {
        webSocketTask?.sendPing { _ in }
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) { [weak self] in
            self?.scheduleHeartbeat()
        }
    }

    private func scheduleReconnect() {
        reconnectTimer?.invalidate()
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }

    // MARK: - URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        isConnected = true
        lastCommand = "Connected to Greyman Server"
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        isConnected = false
        scheduleReconnect()
    }
}
