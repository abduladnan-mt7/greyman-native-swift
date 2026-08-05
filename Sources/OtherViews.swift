// CommandCenterView.swift + LiveStreamView.swift + ProtocolView.swift

import SwiftUI

// MARK: - Command Center (Live server message feed)
struct CommandCenterView: View {
    @EnvironmentObject var wsManager: WebSocketManager
    @State private var commandInput = ""

    var body: some View {
        ZStack {
            BackgroundGradient()
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("COMMAND CENTER")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color("Cyan")).tracking(2)
                    Text("Live Server Feed")
                        .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 60).padding(.bottom, 16)

                // Message Feed
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        ForEach(wsManager.serverMessages) { msg in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(msg.type == .command ? Color("Cyan") : msg.type == .audio ? Color.green : Color.white.opacity(0.3))
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 5)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(msg.text)
                                        .font(.system(size: 14, design: .monospaced))
                                        .foregroundColor(.white.opacity(0.85))
                                    Text(msg.timestamp, style: .time)
                                        .font(.system(size: 10)).foregroundColor(Color("TextSecondary"))
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(Color("CardBG"))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                // Command input bar
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "chevron.right").foregroundColor(Color("Cyan")).font(.system(size: 13, weight: .bold))
                        TextField("Send command to Greyman...", text: $commandInput)
                            .foregroundColor(.white)
                            .font(.system(size: 14, design: .monospaced))
                            .submitLabel(.send)
                            .onSubmit { sendCommand() }
                    }
                    .padding(14)
                    .background(Color("CardBG"))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))

                    Button(action: sendCommand) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 48, height: 48)
                            .background(LinearGradient(colors: [Color("Cyan"), Color("Blue")], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .cornerRadius(14)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Color("BG"))
            }
        }
    }

    func sendCommand() {
        guard !commandInput.isEmpty else { return }
        wsManager.send(text: "{\"type\":\"command\",\"content\":\"\(commandInput)\"}")
        commandInput = ""
    }
}

// MARK: - Live Stream View
struct LiveStreamView: View {
    @EnvironmentObject var audioEngine: AudioEngine
    @State private var visualizerHeights: [CGFloat] = Array(repeating: 4, count: 32)
    @State private var animTimer: Timer?

    var body: some View {
        ZStack {
            BackgroundGradient()
            VStack(spacing: 28) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LIVE STREAM")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color("Cyan")).tracking(2)
                    Text("Greyman Voice Radio")
                        .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20).padding(.top, 60)

                // Visualizer
                GlassCard {
                    VStack(spacing: 20) {
                        HStack(alignment: .bottom, spacing: 3) {
                            ForEach(0..<visualizerHeights.count, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearGradient(colors: [Color("Cyan"), Color("Blue")], startPoint: .bottom, endPoint: .top))
                                    .frame(width: 6, height: visualizerHeights[i])
                                    .animation(.easeInOut(duration: 0.15), value: visualizerHeights[i])
                            }
                        }
                        .frame(height: 60)
                        .onAppear { startVisualizer() }
                        .onDisappear { animTimer?.invalidate() }

                        Text(audioEngine.isPlaying ? "🎙️ LIVE — Greyman Executive Voice" : "Stream Offline")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(audioEngine.isPlaying ? Color("Green") : Color("TextSecondary"))

                        // Big play button
                        Button { audioEngine.toggle() } label: {
                            HStack(spacing: 12) {
                                Image(systemName: audioEngine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 22))
                                Text(audioEngine.isPlaying ? "Pause Stream" : "Start Live Stream")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(LinearGradient(colors: audioEngine.isPlaying ? [Color("Green"), .teal] : [Color("Cyan"), Color("Blue")],
                                startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(14)
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Stream URLs
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("STREAM ENDPOINTS", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color("TextSecondary")).tracking(1)
                        ForEach(AudioEngine.shared.streamURLs, id: \.self) { url in
                            HStack(spacing: 8) {
                                Image(systemName: "dot.radiowaves.right").foregroundColor(Color("Cyan")).font(.system(size: 12))
                                Text(url).font(.system(size: 11, design: .monospaced)).foregroundColor(.white.opacity(0.7)).lineLimit(1)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                Spacer()
            }
        }
    }

    func startVisualizer() {
        animTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            if audioEngine.isPlaying {
                visualizerHeights = (0..<32).map { _ in CGFloat.random(in: 4...56) }
            } else {
                visualizerHeights = Array(repeating: 4, count: 32)
            }
        }
    }
}

// MARK: - Protocol View (Hair Regrowth Checklist)
struct ProtocolView: View {
    @State private var redLight = false
    @State private var finasteride = false
    @State private var redensyl = false
    @State private var dua = false
    @State private var dermaStamp = false
    @State private var oilMask = false

    var completedCount: Int { [redLight, finasteride, redensyl, dua, dermaStamp, oilMask].filter { $0 }.count }

    var body: some View {
        ZStack {
            BackgroundGradient()
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CONFIDENCE FARMING")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(Color("Cyan")).tracking(2)
                        Text("Daily Scalp Protocol")
                            .font(.system(size: 24, weight: .bold)).foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 60)

                    // Progress ring
                    GlassCard {
                        HStack(spacing: 20) {
                            ZStack {
                                Circle().stroke(Color.white.opacity(0.08), lineWidth: 8).frame(width: 72, height: 72)
                                Circle()
                                    .trim(from: 0, to: CGFloat(completedCount) / 6.0)
                                    .stroke(LinearGradient(colors: [Color("Cyan"), Color("Blue")], startPoint: .leading, endPoint: .trailing),
                                        style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                    .frame(width: 72, height: 72)
                                    .rotationEffect(.degrees(-90))
                                    .animation(.spring(), value: completedCount)
                                Text("\(completedCount)/6")
                                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Today's Progress").font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                                Text(completedCount == 6 ? "✅ Full Protocol Complete!" : "\(6 - completedCount) steps remaining")
                                    .font(.system(size: 13)).foregroundColor(Color("TextSecondary"))
                            }
                            Spacer()
                        }
                    }

                    GlassCard {
                        VStack(spacing: 4) {
                            ProtocolRow(icon: "🔴", title: "Red Light Therapy", subtitle: "15-20 min on dry scalp", isChecked: $redLight)
                            ProtocolRow(icon: "🧪", title: "Topical Finasteride", subtitle: "Wait 15 min before next step", isChecked: $finasteride)
                            ProtocolRow(icon: "🌿", title: "Redensyl Application", subtitle: "Apply after Finasteride wait", isChecked: $redensyl)
                            ProtocolRow(icon: "🤲", title: "Recite Dua & Bismillah", subtitle: "Before each application", isChecked: $dua)
                            ProtocolRow(icon: "📍", title: "Derma Stamp (Tues only)", subtitle: "Leave scalp bare after!", isChecked: $dermaStamp)
                            ProtocolRow(icon: "🌰", title: "Oil Mask (Fri 11AM)", subtitle: "Pumpkin, Black Seed, Clove", isChecked: $oilMask)
                        }
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct ProtocolRow: View {
    let icon: String, title: String, subtitle: String
    @Binding var isChecked: Bool

    var body: some View {
        Button { withAnimation(.spring()) { isChecked.toggle() } } label: {
            HStack(spacing: 14) {
                Text(icon).font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isChecked ? Color("TextSecondary") : .white)
                        .strikethrough(isChecked)
                    Text(subtitle).font(.system(size: 11)).foregroundColor(Color("TextSecondary"))
                }
                Spacer()
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isChecked ? Color("Green") : Color.white.opacity(0.2))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
        Divider().background(Color.white.opacity(0.06))
    }
}
