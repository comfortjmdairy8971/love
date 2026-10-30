import Foundation
import Observation
import UIKit

extension Notification.Name {
    static let timerManagerDidChange = Notification.Name("timerManagerDidChange")
}

// MARK: - Shared Activity Timer
/// One process-wide stopwatch so tab switches and backgrounding don't reset elapsed time.
@Observable
@MainActor
final class TimerManager {
    static let shared = TimerManager()

    private(set) var isTiming = false
    private(set) var startDate: Date?
    private(set) var elapsedSeconds: TimeInterval = 0

    private var tickTask: Task<Void, Never>?
    private var tickGeneration = 0

    private init() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.syncFromStartDate()
            }
        }
    }

    func startTimer() {
        startDate = Date()
        elapsedSeconds = 0
        isTiming = true
        startTicking()
        notify()
    }

    func pauseTimer() {
        stopTicking()
        if isTiming, let startDate {
            elapsedSeconds = Date().timeIntervalSince(startDate)
        }
        isTiming = false
        notify()
    }

    /// Continues from the frozen elapsed time after a pause.
    func resumeTimer() {
        startDate = Date().addingTimeInterval(-elapsedSeconds)
        isTiming = true
        startTicking()
        notify()
    }

    func resetTimer() {
        stopTicking()
        isTiming = false
        startDate = nil
        elapsedSeconds = 0
        notify()
    }

    /// Recalculates elapsed time from `startDate` (call when the scene becomes active).
    func syncFromStartDate() {
        guard isTiming, let startDate else { return }
        elapsedSeconds = Date().timeIntervalSince(startDate)
        notify()
    }

    private func startTicking() {
        stopTicking()
        tickGeneration += 1
        let generation = tickGeneration
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled, self.isTiming, self.tickGeneration == generation else { return }
                self.syncFromStartDate()
            }
        }
    }

    private func stopTicking() {
        tickGeneration += 1
        tickTask?.cancel()
        tickTask = nil
    }

    private func notify() {
        NotificationCenter.default.post(name: .timerManagerDidChange, object: self)
    }
}
