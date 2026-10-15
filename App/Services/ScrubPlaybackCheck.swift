#if DEBUG
import Foundation

/// Opt-in runtime check of the real audio graph, used when simulator UI automation is unavailable.
@MainActor
enum ScrubPlaybackCheck {
    static func run(controller: MetronomeController) async {
        controller.settings.bpm = 120
        controller.settings.hapticsEnabled = false
        controller.start()
        do {
            try await Task.sleep(for: .milliseconds(800))
            guard controller.isRunning else {
                NSLog("METRO STATION SCRUB FAIL: audio graph did not start: %@", controller.errorMessage ?? "unknown")
                return
            }
            controller.beginScrub()
            defer { controller.endScrub() }
            var previous = controller.snapshot(at: .now).absoluteBeatPosition
            var updates = 0
            for index in 0..<240 {
                // Whole BPM edits span the full range in both directions.
                let step = index < 120 ? index : 239 - index
                let tempo = 30 + Double(step) * 210 / 119
                controller.scrubTempo(to: tempo.rounded())
                try await Task.sleep(for: .milliseconds(25))
                let current = controller.snapshot(at: .now).absoluteBeatPosition
                guard controller.isRunning, current >= previous else {
                    NSLog("METRO STATION SCRUB FAIL: clock stopped or rewound at update %d: %.6f -> %.6f; %@",
                          index, previous, current, controller.errorMessage ?? "no error")
                    return
                }
                previous = current
                updates += 1
            }
            controller.scrubTempo(to: 120)
            try await Task.sleep(for: .milliseconds(100))
            for direction in [1, 1, -1, -1] {
                let expected = controller.settings.bpm + Double(direction)
                controller.stepTempo(direction: direction)
                try await Task.sleep(for: .milliseconds(60))
                guard controller.settings.bpm == expected,
                      controller.effectiveSettings.bpm == expected,
                      controller.isRunning else {
                    NSLog("METRO STATION CROWN FAIL: one BPM step was not acknowledged")
                    return
                }
            }
            for (direction, expected) in [(1, 168.0), (1, 200.0), (-1, 168.0), (-1, 120.0), (-1, 108.0), (1, 120.0)] {
                controller.stepTempoMarking(direction: direction)
                try await Task.sleep(for: .milliseconds(60))
                let current = controller.snapshot(at: .now).absoluteBeatPosition
                guard controller.settings.bpm == expected,
                      controller.effectiveSettings.bpm == expected,
                      controller.isRunning, current >= previous else {
                    NSLog("METRO STATION CROWN FAIL: marking jump was not acknowledged or transport rewound")
                    return
                }
                previous = current
            }
            // Old fractional settings and external callers must resolve to a whole BPM.
            controller.settings.bpm = 121.4
            try await Task.sleep(for: .milliseconds(200))
            guard controller.settings.bpm == 121, controller.effectiveSettings.bpm == 121 else {
                NSLog("METRO STATION CROWN FAIL: direct setting normalization did not reach the audio graph")
                return
            }
            controller.scrubTempo(to: 120.4)
            try await Task.sleep(for: .milliseconds(200))
            guard controller.settings.bpm == 120, controller.effectiveSettings.bpm == 120,
                  controller.snapshot(at: .now).absoluteBeatPosition > previous else {
                NSLog("METRO STATION CROWN FAIL: whole BPM enforcement was not acknowledged by the audio graph")
                return
            }
            NSLog("METRO STATION CROWN PASS: %d live updates, four one-BPM steps, six marking jumps; continuous beat position %.6f, acknowledged %d BPM",
                  updates, controller.snapshot(at: .now).absoluteBeatPosition, Int(controller.effectiveSettings.bpm))
        } catch {
            NSLog("METRO STATION SCRUB CANCELLED: %@", error.localizedDescription)
        }
    }
}
#endif
