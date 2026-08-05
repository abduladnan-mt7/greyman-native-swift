// PermissionsManager.swift
// Manages Mic, Camera, Speech Recognition permissions

import Foundation
import AVFoundation
import Speech
import Combine

class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var micGranted = false
    @Published var cameraGranted = false
    @Published var speechGranted = false
    @Published var isRecording = false
    @Published var transcribedText = ""

    private var audioEngine = AVAudioEngine()
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    func requestAll() {
        requestMic()
        requestCamera()
        requestSpeech()
    }

    func requestMic() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async { self?.micGranted = granted }
        }
    }

    func requestCamera() {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async { self?.cameraGranted = granted }
        }
    }

    func requestSpeech() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.speechGranted = status == .authorized
            }
        }
    }

    func startVoiceCommand(completion: @escaping (String) -> Void) {
        guard micGranted, speechGranted else { requestAll(); return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        try? audioEngine.start()
        isRecording = true

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            if let result = result {
                let text = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self?.transcribedText = text
                    if result.isFinal { completion(text) }
                }
            }
            if error != nil || result?.isFinal == true {
                self?.stopVoiceCommand()
            }
        }
    }

    func stopVoiceCommand() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        isRecording = false
    }
}
