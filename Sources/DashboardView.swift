// DashboardView.swift
// ServerCat-inspired executive server stats dashboard

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var wsManager: WebSocketManager
    @EnvironmentObject var permissions: PermissionsManager
    @State private var pulseAnim = false

    var body: some View {
        ZStack {
            BackgroundGradient()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("GREYMAN EXECUTIVE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(Color("Cyan"))
                                .tracking(2)
                            Text("Boss Command Center")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        // Dynamic Island style pulse
                        ZStack {
                            Circle()
                                .fill(Color("Cyan").opacity(0.15))
                                .frame(width: 48, height: 48)
                                .scaleEffect(pulseAnim ? 1.2 : 1.0)
                                .animation(.easeInOut(duration: 1.2).repeatForever(), value: pulseAnim)
                            Image(systemName: "person.fill.checkmark")
                                .font(.system(size: 18))
                                .foregroundColor(Color("Cyan"))
                        }
                        .onAppear { pulseAnim = true }
                    }
                    .padding(.top, 60)

                    // Server Connection Card (ServerCat style)
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Label("GREYMAN SERVER", systemImage: "server.rack")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color("TextSecondary"))
                                    .tracking(1)
                                Spacer()
                                StatusPill(connected: wsManager.isConnected)
                            }

                            Divider().background(Color.white.opacity(0.08))

                            HStack(spacing: 16) {
                                MetricTile(icon: "bolt.fill", label: "LATENCY", value: wsManager.isConnected ? "12ms" : "--", color: .green)
                                MetricTile(icon: "arrow.up.arrow.down", label: "STREAM", value: audioEngine.isPlaying ? "LIVE" : "IDLE", color: audioEngine.isPlaying ? .cyan : .orange)
                                MetricTile(icon: "speaker.wave.3.fill", label: "OUTPUT", value: audioEngine.outputRoute, color: .purple)
                            }

                            if !wsManager.lastCommand.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "terminal.fill")
                                        .foregroundColor(Color("Cyan"))
                                        .font(.system(size: 12))
                                    Text(wsManager.lastCommand)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.8))
                                        .lineLimit(1)
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(8)
                            }
                        }
                    }

                    // Audio Engine Card
                    GlassCard {
                        VStack(spacing: 16) {
                            HStack {
                                Label("LIVE VOICE ENGINE", systemImage: "waveform")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundColor(Color("TextSecondary"))
                                    .tracking(1)
                                Spacer()
                            }

                            // Big play button
                            Button {
                                audioEngine.toggle()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: audioEngine.isPlaying ? [Color("Green"), Color.teal] : [Color("Cyan"), Color("Blue")],
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 72, height: 72)
                                        .shadow(color: audioEngine.isPlaying ? Color.green.opacity(0.5) : Color("Cyan").opacity(0.4), radius: 16)

                                    Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }

                            Text(audioEngine.isConnecting ? "Connecting..." : audioEngine.isPlaying ? "🎙️ Greyman Voice Live" : "Tap to Start Stream")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(audioEngine.isPlaying ? Color("Green") : .white.opacity(0.6))

                            // Volume Slider
                            HStack(spacing: 12) {
                                Image(systemName: "speaker.fill").foregroundColor(Color("TextSecondary")).font(.system(size: 13))
                                Slider(value: Binding(get: { Double(audioEngine.volume) }, set: { audioEngine.setVolume(Float($0)) }), in: 0...1)
                                    .tint(Color("Cyan"))
                                Image(systemName: "speaker.wave.3.fill").foregroundColor(Color("TextSecondary")).font(.system(size: 13))
                            }

                            // Speaker/Earpiece toggle
                            HStack(spacing: 12) {
                                RouteButton(label: "Speaker", icon: "speaker.wave.2.fill", active: audioEngine.outputRoute == "Speaker") {
                                    audioEngine.routeToSpeaker()
                                }
                                RouteButton(label: "Earpiece", icon: "ear.fill", active: audioEngine.outputRoute == "Earpiece") {
                                    audioEngine.routeToEarpiece()
                                }
                            }
                        }
                    }

                    // Mic Voice Command Card
                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("VOICE COMMAND", systemImage: "mic.fill")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Color("TextSecondary"))
                                .tracking(1)

                            Button {
                                if permissions.isRecording {
                                    permissions.stopVoiceCommand()
                                } else {
                                    permissions.startVoiceCommand { text in
                                        wsManager.send(text: "{\"type\":\"command\",\"content\":\"\(text)\"}")
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: permissions.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(permissions.isRecording ? Color("Green") : Color("Cyan"))
                                    Text(permissions.isRecording ? "Listening... Tap to Send" : "Hold to Speak to Greyman")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(14)
                                .background(permissions.isRecording ? Color.green.opacity(0.12) : Color.white.opacity(0.05))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(
                                    permissions.isRecording ? Color.green.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1))
                            }

                            if !permissions.transcribedText.isEmpty {
                                Text("\" \(permissions.transcribedText) \"")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.7))
                                    .italic()
                            }
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

// MARK: - Reusable Components
struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(18)
            .background(Color("CardBG"))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.08), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 12)
    }
}

struct MetricTile: View {
    let icon: String, label: String, value: String
    let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(color)
            Text(value).font(.system(size: 13, weight: .bold, design: .monospaced)).foregroundColor(.white)
            Text(label).font(.system(size: 9, weight: .bold)).foregroundColor(Color("TextSecondary")).tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }
}

struct StatusPill: View {
    let connected: Bool
    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(connected ? Color.green : Color.orange).frame(width: 7, height: 7)
            Text(connected ? "CONNECTED" : "RECONNECTING")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(connected ? .green : .orange)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(connected ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
        .cornerRadius(20)
    }
}

struct RouteButton: View {
    let label: String, icon: String, active: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 13))
                Text(label).font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(active ? .black : .white.opacity(0.6))
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(active ? Color("Cyan") : Color.white.opacity(0.06))
            .cornerRadius(10)
        }
    }
}

struct BackgroundGradient: View {
    var body: some View {
        LinearGradient(colors: [Color(red: 0.04, green: 0.07, blue: 0.14), Color(red: 0.02, green: 0.03, blue: 0.08)],
            startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea()
    }
}
