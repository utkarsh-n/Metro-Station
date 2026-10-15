import CoreMotion
import Observation

/// Gravity drives the instrument's reflections; no integrated angles can drift.
@MainActor
@Observable
final class MotionLighting {
    private(set) var x = 0.0
    private(set) var y = 0.0
    private(set) var isAvailable = false
    private(set) var isActive = false
    #if DEBUG
    private(set) var sampleCount = 0
    private(set) var lastGravity = SIMD3<Double>.zero
    private(set) var lastSampleTimestamp = 0.0
    #endif

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private var referenceX = 0.0
    @ObservationIgnored private var referenceY = 0.0
    @ObservationIgnored private var hasReference = false

    init() {
        isAvailable = manager.isDeviceMotionAvailable
    }

    func start() {
        guard isAvailable, !isActive else { return }
        hasReference = false
        #if DEBUG
        sampleCount = 0
        #endif
        isActive = true
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] update, error in
            let gravityX = update?.gravity.x
            let gravityZ = update?.gravity.z
            #if DEBUG
            let gravityY = update?.gravity.y
            let timestamp = update?.timestamp
            #endif
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.isActive else { return }
                if failed {
                    self.stop()
                    return
                }
                guard let gravityX, let gravityZ else { return }
                #if DEBUG
                if let gravityY, let timestamp {
                    self.lastGravity = SIMD3(gravityX, gravityY, gravityZ)
                    self.lastSampleTimestamp = timestamp
                    self.sampleCount += 1
                }
                #endif
                if !self.hasReference {
                    self.referenceX = gravityX
                    self.referenceY = gravityZ
                    self.hasReference = true
                }
                let nextX = min(1, max(-1, (gravityX - self.referenceX) * 1.7))
                let nextY = min(1, max(-1, (gravityZ - self.referenceY) * 1.7))
                // A short, fixed low-pass filter removes hand tremor without a
                // rolling baseline that would erase the user's held tilt.
                self.x += (nextX - self.x) * 0.18
                self.y += (nextY - self.y) * 0.18
            }
        }
    }

    func stop() {
        manager.stopDeviceMotionUpdates()
        isActive = false
        hasReference = false
        x = 0
        y = 0
    }
}
