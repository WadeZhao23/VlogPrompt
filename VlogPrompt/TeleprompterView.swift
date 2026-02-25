import SwiftUI
import AVKit
import Speech

struct TeleprompterView: View {
    let scriptContent: String

    @StateObject private var viewModel = TeleprompterViewModel()
    @StateObject private var speechService = SpeechRecognitionService()
    @StateObject private var pipManager = PiPManager()

    @State private var audioBarHeights: [CGFloat] = [12, 20, 8, 24, 12, 16, 8]
    @State private var audioBarTimer: Timer?
    @Environment(\.dismiss) private var dismiss

    private var paragraphs: [String] {
        scriptContent
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        ZStack {
            // Camera background (black base)
            Color.black.ignoresSafeArea()

            // Hidden PiP source view - 1×1 UIView used as PiP anchor
            PiPSourceUIView(
                pipManager: pipManager,
                contentView: AnyView(pipContentView)
            )
            .frame(width: 1, height: 1)
            .opacity(0.001)

            // Cinematic gradient overlay (top dark → clear → bottom dark)
            LinearGradient(
                stops: [
                    .init(color: Color.black.opacity(0.7), location: 0),
                    .init(color: Color.black.opacity(0.08), location: 0.4),
                    .init(color: Color.black.opacity(0.82), location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topControlBar
                    .padding(.horizontal, 20)
                    .padding(.top, 52)
                    .padding(.bottom, 16)

                teleprompterPanel
                    .padding(.horizontal, 20)

                Spacer(minLength: 24)

                bottomControls
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
            }
        }
        .navigationBarHidden(true)
        .preferredColorScheme(.dark)
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            viewModel.loadScript(scriptContent)
            startAudioAnimation()
            Task { await speechService.requestAuthorization() }
        }
        .onDisappear {
            viewModel.pause()
            speechService.stopRecognition()
            audioBarTimer?.invalidate()
            pipManager.stopPiP()
        }
        .onChange(of: speechService.recognizedText) { _, newText in
            viewModel.updatePosition(from: newText)
        }
        .onChange(of: viewModel.currentParagraphIndex) { _, _ in
            pipManager.updateContent(pipContentView)
        }
    }


    private var pipContentView: some View {
        TeleprompterPiPContentView(
            paragraphs: paragraphs,
            currentIndex: viewModel.currentParagraphIndex,
            fontSize: viewModel.fontSize
        )
    }

    // MARK: - Top Control Bar

    private var topControlBar: some View {
        HStack {
            circularButton(icon: "gearshape") {}

            Spacer()

            // Privacy indicator pill
            HStack(spacing: 6) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12))
                    .foregroundColor(Color.appPrimary)
                Text("Local Mode")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(2.0)
                    .foregroundColor(.white.opacity(0.9))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.3))
                    .overlay(Capsule().stroke(Color.white.opacity(0.1), lineWidth: 1))
            )
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            circularButton(icon: "camera.rotate") {}
        }
    }

    private func circularButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.3))
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                )
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    // MARK: - Teleprompter Panel

    private var teleprompterPanel: some View {
        VStack(spacing: 0) {
            panelHeader

            GeometryReader { geo in
                ZStack(alignment: .top) {
                    scriptScrollView(geo: geo)

                    // Eye contact guide line at 35% height
                    Rectangle()
                        .fill(Color.appPrimary.opacity(0.2))
                        .frame(height: 1)
                        .padding(.horizontal, 24)
                        .offset(y: geo.size.height * 0.35)
                        .allowsHitTesting(false)

                    // Bottom text fade mask
                    VStack {
                        Spacer()
                        LinearGradient(
                            colors: [.clear, Color.glassDark.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 80)
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: UIScreen.main.bounds.height * 0.42)

            audioVisualizer
                .padding(.bottom, 10)
                .opacity(0.4)
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.glassDark.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.05), lineWidth: 1)
                )
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: .infinity)
    }

    private var panelHeader: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "speedometer")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.5))
                Text("\(Int(viewModel.wordsPerMinute)) wpm")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // PiP toggle button
            Button {
                pipManager.togglePiP()
            } label: {
                Image(systemName: pipManager.isPiPActive ? "pip.exit" : "pip.enter")
                    .font(.system(size: 14))
                    .foregroundColor(pipManager.isPiPActive ? Color.appPrimary : .white.opacity(0.4))
            }
            .padding(.trailing, 8)
            .opacity(pipManager.isPiPSupported ? 1 : 0.3)
            .disabled(!pipManager.isPiPSupported)

            HStack(spacing: 4) {
                Circle()
                    .fill(Color.appPrimary)
                    .frame(width: 5, height: 5)
                    .opacity(viewModel.isPlaying ? 1 : 0.5)
                    .scaleEffect(viewModel.isPlaying ? 1.2 : 1.0)
                    .animation(
                        viewModel.isPlaying
                            ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: viewModel.isPlaying
                    )
                Text(viewModel.isPlaying ? "LIVE" : "READY")
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2.5)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.white.opacity(0.05)),
            alignment: .bottom
        )
    }

    @ViewBuilder
    private func scriptScrollView(geo: GeometryProxy) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    Color.clear.frame(height: geo.size.height * 0.3)

                    ForEach(paragraphs.indices, id: \.self) { index in
                        Text(paragraphs[index])
                            .font(.system(
                                size: viewModel.fontSize,
                                weight: index == viewModel.currentParagraphIndex ? .semibold : .medium
                            ))
                            .foregroundColor(.white.opacity(paragraphOpacity(at: index)))
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                            .padding(.horizontal, 24)
                            .id(index)
                    }

                    Color.clear.frame(height: geo.size.height * 0.6)
                }
            }
            .onChange(of: viewModel.currentParagraphIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.5)) {
                    proxy.scrollTo(newIndex, anchor: UnitPoint(x: 0.5, y: 0.32))
                }
            }
        }
    }

    private func paragraphOpacity(at index: Int) -> Double {
        let diff = index - viewModel.currentParagraphIndex
        switch diff {
        case ..<0: return 0.25
        case 0:    return 0.92
        case 1:    return 1.0
        case 2:    return 0.6
        default:   return 0.3
        }
    }

    // MARK: - Audio Visualizer

    private var audioVisualizer: some View {
        HStack(spacing: 3) {
            ForEach(audioBarHeights.indices, id: \.self) { i in
                Capsule()
                    .fill(Color.white)
                    .frame(width: 4, height: audioBarHeights[i])
                    .animation(.easeInOut(duration: 0.25), value: audioBarHeights[i])
            }
        }
        .frame(height: 40)
    }

    private func startAudioAnimation() {
        audioBarTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            Task { @MainActor in
                if self.viewModel.isPlaying || self.speechService.isRecognizing {
                    self.audioBarHeights = (0..<7).map { _ in CGFloat.random(in: 4...28) }
                } else {
                    self.audioBarHeights = [4, 6, 4, 8, 4, 6, 4]
                }
            }
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 24) {
            fontSizeSlider
            mainControlRow
        }
    }

    private var fontSizeSlider: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.fontSize = max(14, viewModel.fontSize - 2)
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.appPrimary.opacity(0.8))
                        .frame(
                            width: geo.size.width * CGFloat((viewModel.fontSize - 14) / 30.0),
                            height: 4
                        )
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let ratio = max(0, min(1, value.location.x / geo.size.width))
                            viewModel.fontSize = 14 + ratio * 30
                        }
                )
            }
            .frame(height: 4)

            Button {
                viewModel.fontSize = min(44, viewModel.fontSize + 2)
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16))
                    .foregroundColor(.white.opacity(0.5))
            }

            Text("Font Size")
                .font(.system(size: 11, weight: .medium))
                .tracking(1.5)
                .foregroundColor(.white.opacity(0.5))
                .frame(minWidth: 58, alignment: .trailing)
        }
    }

    private var mainControlRow: some View {
        HStack {
            // Script button (return to edit)
            sideButton(icon: "square.and.pencil", label: "SCRIPT") {
                dismiss()
            }

            Spacer()

            // Primary FAB
            fabButton

            Spacer()

            // Reset button
            sideButton(icon: "arrow.counterclockwise", label: "RESET") {
                viewModel.reset()
                if speechService.isRecognizing { speechService.stopRecognition() }
            }
        }
    }

    private func sideButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                Text(label)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(2.0)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
    }

    private var fabButton: some View {
        Button {
            handleFABTap()
        } label: {
            ZStack {
                // Glow halo
                Circle()
                    .fill(Color.appPrimary.opacity(0.2))
                    .frame(width: 88, height: 88)
                    .blur(radius: 18)

                // Main circle
                Circle()
                    .fill(Color.appPrimary.opacity(0.9))
                    .frame(width: 76, height: 76)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                // Inner icon on white rounded rect
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: fabIcon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color.appPrimary)
                    )
            }
        }
        .scaleEffect(viewModel.isPlaying ? 1.0 : 0.95)
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.isPlaying)
    }

    private var fabIcon: String {
        if viewModel.isPlaying {
            return "pause.fill"
        } else {
            return "play.fill"
        }
    }

    private func handleFABTap() {
        if viewModel.isPlaying {
            viewModel.pause()
            if speechService.isRecognizing { speechService.stopRecognition() }
        } else {
            viewModel.play()
            if speechService.authorizationStatus == .authorized {
                try? speechService.startRecognition()
            }
        }
    }
}

// MARK: - PiP Content View

struct TeleprompterPiPContentView: View {
    let paragraphs: [String]
    let currentIndex: Int
    let fontSize: Double

    var body: some View {
        ZStack {
            Color.glassDark.ignoresSafeArea()
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        ForEach(paragraphs.indices, id: \.self) { i in
                            Text(paragraphs[i])
                                .font(.system(size: fontSize * 0.7, weight: i == currentIndex ? .semibold : .regular))
                                .foregroundColor(.white.opacity(i == currentIndex ? 0.95 : 0.4))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                                .id(i)
                        }
                    }
                    .padding(.vertical, 20)
                }
                .onChange(of: currentIndex) { _, newIdx in
                    withAnimation { proxy.scrollTo(newIdx, anchor: .center) }
                }
            }
        }
    }
}

#Preview {
    TeleprompterView(scriptContent: "Welcome to VlogPrompt.\n\nThis is your secure, private space to create content with confidence.\n\nYour script will scroll here smoothly, keeping your eyes near the camera lens for perfect engagement.\n\nFocus on your delivery — we'll handle the pacing.")
}
