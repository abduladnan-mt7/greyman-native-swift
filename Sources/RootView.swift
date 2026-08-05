// RootView.swift
// Main navigation shell — ServerCat/ActivityWatch-inspired dark premium UI

import SwiftUI

struct RootView: View {
    @State private var selectedTab = 0
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var wsManager: WebSocketManager

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                DashboardView()
                    .tag(0)
                CommandCenterView()
                    .tag(1)
                LiveStreamView()
                    .tag(2)
                ProtocolView()
                    .tag(3)
            }

            // Custom Premium Navbar
            PremiumNavBar(selectedTab: $selectedTab)
                .padding(.bottom, 8)
        }
        .ignoresSafeArea(edges: .bottom)
        .background(Color("BG").ignoresSafeArea())
    }
}

// MARK: - Premium ServerCat-style Navbar
struct PremiumNavBar: View {
    @Binding var selectedTab: Int
    @EnvironmentObject var wsManager: WebSocketManager

    let tabs: [(icon: String, label: String)] = [
        ("waveform.badge.plus", "Dashboard"),
        ("bolt.fill", "Commands"),
        ("antenna.radiowaves.left.and.right", "Stream"),
        ("leaf.fill", "Protocol")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { i in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = i
                    }
                } label: {
                    VStack(spacing: 4) {
                        ZStack {
                            if selectedTab == i {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(LinearGradient(colors: [Color("Cyan"), Color("Blue")], startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 44, height: 32)
                            }
                            Image(systemName: tabs[i].icon)
                                .font(.system(size: 16, weight: selectedTab == i ? .bold : .regular))
                                .foregroundColor(selectedTab == i ? .black : Color("TextSecondary"))
                        }
                        Text(tabs[i].label)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(selectedTab == i ? Color("Cyan") : Color("TextSecondary"))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Color("CardBG")
                    .opacity(0.95)
                // Live server status indicator
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(wsManager.isConnected ? Color.green : Color.orange)
                            .frame(width: 6, height: 6)
                        Text(wsManager.isConnected ? "LIVE" : "...")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(wsManager.isConnected ? .green : .orange)
                    }
                    .padding(.trailing, 12)
                    .padding(.top, -28)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .shadow(color: .black.opacity(0.4), radius: 20, y: -4)
        )
        .padding(.horizontal, 20)
    }
}
