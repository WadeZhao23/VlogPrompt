import Foundation
import Combine
import SwiftUI

class TeleprompterViewModel: ObservableObject {
    @Published var isPlaying: Bool = false
    @Published var currentParagraphIndex: Int = 0
    @Published var fontSize: Double = 24
    @Published var wordsPerMinute: Double = 145

    private var paragraphs: [String] = []
    private var scrollTimer: Timer?

    func loadScript(_ content: String) {
        paragraphs = content
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        currentParagraphIndex = 0
    }

    var totalParagraphs: Int { paragraphs.count }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard !paragraphs.isEmpty else { return }
        isPlaying = true
        startScrollTimer()
    }

    func pause() {
        isPlaying = false
        stopScrollTimer()
    }

    func reset() {
        pause()
        currentParagraphIndex = 0
    }

    // MARK: - Speech Recognition Position Update

    func updatePosition(from recognizedText: String) {
        guard !paragraphs.isEmpty, !recognizedText.isEmpty else { return }

        let recognizedWords = recognizedText
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }

        guard recognizedWords.count >= 3 else { return }

        let windowSize = min(5, recognizedWords.count)
        let recentWords = Array(recognizedWords.suffix(windowSize))

        var bestMatchIndex = currentParagraphIndex
        var bestScore = 0

        let searchStart = max(0, currentParagraphIndex - 2)
        let searchEnd = min(paragraphs.count, searchStart + 30)

        for i in searchStart..<searchEnd {
            let paragraphWords = paragraphs[i]
                .lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .map { $0.trimmingCharacters(in: .punctuationCharacters) }

            var score = 0
            for word in recentWords {
                if paragraphWords.contains(word) { score += 1 }
            }

            if score > bestScore {
                bestScore = score
                bestMatchIndex = i
            }
        }

        if bestScore >= windowSize / 2 {
            currentParagraphIndex = bestMatchIndex
        }
    }

    // MARK: - Auto Scroll Timer

    private func startScrollTimer() {
        stopScrollTimer()
        let interval = calculateScrollInterval()
        scrollTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.isPlaying else { return }
                if self.currentParagraphIndex < self.paragraphs.count - 1 {
                    self.currentParagraphIndex += 1
                } else {
                    self.pause()
                }
            }
        }
    }

    private func stopScrollTimer() {
        scrollTimer?.invalidate()
        scrollTimer = nil
    }

    private func calculateScrollInterval() -> TimeInterval {
        guard !paragraphs.isEmpty else { return 3.0 }
        let currentPara = paragraphs[safe: currentParagraphIndex] ?? ""
        let wordCount = max(1, currentPara.components(separatedBy: .whitespaces).filter { !$0.isEmpty }.count)
        let secondsPerWord = 60.0 / wordsPerMinute
        return Double(wordCount) * secondsPerWord
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
