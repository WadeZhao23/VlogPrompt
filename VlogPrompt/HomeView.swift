import SwiftUI

struct HomeView: View {
    @State private var scriptText: String = ""
    @State private var statusVisible: Bool = false
    @State private var pulseScale: CGFloat = 0.8
    @State private var pulseOpacity: Double = 0.6
    @State private var navigateToTeleprompter: Bool = false
    @State private var showSettings: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.appBackground.ignoresSafeArea()

                // Top-left green glow
                Circle()
                    .fill(Color.appPrimary.opacity(0.1))
                    .frame(width: 320, height: 320)
                    .blur(radius: 100)
                    .offset(x: -100, y: -200)
                    .allowsHitTesting(false)

                // Bottom-right green glow
                Circle()
                    .fill(Color.appPrimary.opacity(0.05))
                    .frame(width: 380, height: 380)
                    .blur(radius: 120)
                    .offset(x: 140, y: 280)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    headerBar

                    // Main editor area
                    VStack(alignment: .leading, spacing: 8) {
                        statusRow

                        ZStack(alignment: .bottom) {
                            textEditorArea

                            // Bottom fade to background
                            LinearGradient(
                                colors: [.clear, Color.appBackground],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 52)
                            .allowsHitTesting(false)
                        }
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    bottomActions
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(0.1)) {
                    statusVisible = true
                }
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.2
                    pulseOpacity = 1.0
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsPlaceholderView()
            }
            .navigationDestination(isPresented: $navigateToTeleprompter) {
                TeleprompterView(scriptContent: scriptText)
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Spacer()
                .frame(width: 40)

            Spacer()

            Text("VlogPrompt")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3.5)
                .foregroundColor(Color.white.opacity(0.4))
                .textCase(.uppercase)

            Spacer()

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 20))
                    .foregroundColor(Color.white.opacity(0.5))
            }
            .frame(width: 40)
        }
        .padding(.horizontal, 24)
        .padding(.top, 56)
        .padding(.bottom, 16)
    }

    // MARK: - Status Row

    private var statusRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.appPrimary)
                .frame(width: 6, height: 6)
                .scaleEffect(pulseScale)
                .opacity(pulseOpacity)

            Text("NEW SCRIPT")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.5)
                .foregroundColor(Color.white.opacity(0.5))
        }
        .opacity(statusVisible ? 1 : 0)
        .offset(y: statusVisible ? 0 : 5)
        .animation(.easeOut(duration: 0.5), value: statusVisible)
        .padding(.bottom, 2)
    }

    // MARK: - Text Editor

    private var textEditorArea: some View {
        ZStack(alignment: .topLeading) {
            if scriptText.isEmpty {
                Text("Start writing your story here...")
                    .font(.system(size: 26, weight: .light))
                    .foregroundColor(Color.white.opacity(0.2))
                    .padding(.top, 8)
                    .padding(.leading, 5)
                    .allowsHitTesting(false)
            }

            TextEditor(text: $scriptText)
                .font(.system(size: 26, weight: .light))
                .foregroundColor(.white.opacity(0.95))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .tint(Color.appPrimary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        VStack(spacing: 20) {
            // Quick toolbar pill
            quickToolbar

            // Start button
            Button {
                guard !scriptText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                navigateToTeleprompter = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 18))
                    Text("Start")
                        .font(.system(size: 18, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(width: 200)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.appPrimary.opacity(scriptText.isEmpty ? 0.4 : 0.9))
                )
                .shadow(color: Color.appPrimary.opacity(scriptText.isEmpty ? 0 : 0.3), radius: 20)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.15), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(scriptText.isEmpty ? 0 : 1)
                )
            }

            // Status hint
            Text("Ready to record")
                .font(.system(size: 10, weight: .medium))
                .tracking(3.0)
                .foregroundColor(Color.white.opacity(0.35))
                .textCase(.uppercase)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .padding(.top, 8)
    }

    // MARK: - Quick Toolbar

    private var quickToolbar: some View {
        HStack(spacing: 24) {
            toolbarButton(icon: "textformat.size")
            toolbarDivider
            toolbarButton(icon: "speedometer")
            toolbarDivider
            toolbarButton(icon: "timer")
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.05))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
    }

    private func toolbarButton(icon: String) -> some View {
        Button {} label: {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color.white.opacity(0.45))
        }
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.2))
            .frame(width: 1, height: 12)
    }
}

// MARK: - Settings Placeholder

private struct SettingsPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            VStack(spacing: 16) {
                Text("Settings")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                Text("Coming soon")
                    .foregroundColor(Color.white.opacity(0.4))
                Button("Close") { dismiss() }
                    .foregroundColor(Color.appPrimary)
                    .padding(.top, 8)
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    HomeView()
}
