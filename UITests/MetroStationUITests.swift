import XCTest
import UIKit

final class MetroStationUITests: XCTestCase {
    @MainActor
    func testTransportAndIndependentSoundSwitch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        let transport = app.buttons["transportButton"]
        XCTAssertTrue(transport.waitForExistence(timeout: 10))
        XCTAssertTrue(transport.label.contains("Start clock"))
        transport.tap()
        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].waitForExistence(timeout: 5))
        let sound = app.buttons["soundButton"]
        sound.tap()
        XCTAssertEqual(sound.value as? String, "Off")
        XCTAssertTrue(transport.label.contains("Stop clock"))
        transport.tap()
        XCTAssertTrue(app.staticTexts["READY TO PLAY"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testTempoPresetAndPhysics() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["controlsButton"].tap()
        let preset = app.buttons["preset60"]
        XCTAssertTrue(preset.waitForExistence(timeout: 3))
        preset.tap()
        XCTAssertEqual(app.staticTexts["tempoValue"].label, "60 BPM")
        app.buttons["controlsDone"].tap()
        app.buttons["physicsButton"].tap()
        XCTAssertTrue(app.staticTexts["Two different frequencies"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["1.00 Hz"].exists)
        app.buttons["physicsDone"].tap()
        XCTAssertTrue(app.buttons["transportButton"].exists)
    }

    @MainActor
    func testCrownAdjustmentsDoNotScrollInstrument() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--physical-qa"]
        app.launch()

        let fine = element("fineTempoCrown", in: app)
        let marking = element("markingTempoCrown", in: app)
        XCTAssertTrue(app.scrollViews["instrumentScroll"].exists)
        XCTAssertTrue(fine.waitForExistence(timeout: 10))
        XCTAssertTrue(marking.isHittable)
        XCTAssertEqual(try crownBPM(fine), 120)

        let transport = app.buttons["transportButton"]
        transport.tap()
        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].waitForExistence(timeout: 5))
        let playingFrames = crownFrames(in: app)

        // Exercise both kinds of buttons while audio acknowledgement replaces
        // APPLYING SETTINGS with CLOCK RUNNING, which previously shifted content.
        app.buttons["fineTempoPlus"].tap()
        XCTAssertEqual(try crownBPM(fine), 121)
        assertRunningControlsStayPut(app, frames: playingFrames)
        app.buttons["fineTempoMinus"].tap()
        XCTAssertEqual(try crownBPM(fine), 120)
        assertRunningControlsStayPut(app, frames: playingFrames)
        app.buttons["markingTempoPlus"].tap()
        XCTAssertEqual(try crownBPM(fine), 168)
        XCTAssertTrue((marking.value as? String)?.contains("Presto") == true)
        assertRunningControlsStayPut(app, frames: playingFrames)
        app.buttons["markingTempoMinus"].tap()
        XCTAssertEqual(try crownBPM(fine), 120)
        XCTAssertTrue((marking.value as? String)?.contains("Allegro") == true)
        assertRunningControlsStayPut(app, frames: playingFrames)

        // Begin on the visible rim, where the enclosing ScrollView used to
        // compete with angular drags. Exercise both directions during playback.
        let beforeFineIncrease = try crownBPM(fine)
        dragFromRim(fine, increasing: true)
        XCTAssertGreaterThan(try crownBPM(fine), beforeFineIncrease)
        assertRunningControlsStayPut(app, frames: playingFrames)
        let beforeFineDecrease = try crownBPM(fine)
        dragFromRim(fine, increasing: false)
        XCTAssertLessThan(try crownBPM(fine), beforeFineDecrease)
        assertRunningControlsStayPut(app, frames: playingFrames)
        let beforeMarkingDrag = try crownBPM(fine)
        let beforeMarkingIncrease = try crownMarking(marking)
        dragFromRim(marking, increasing: true)
        XCTAssertGreaterThan(try crownBPM(fine), beforeMarkingDrag)
        XCTAssertNotEqual(try crownMarking(marking), beforeMarkingIncrease)
        assertRunningControlsStayPut(app, frames: playingFrames)
        let beforeMarkingDecrease = try crownBPM(fine)
        let beforeDecreasingBand = try crownMarking(marking)
        dragFromRim(marking, increasing: false)
        XCTAssertLessThan(try crownBPM(fine), beforeMarkingDecrease)
        XCTAssertNotEqual(try crownMarking(marking), beforeDecreasingBand)
        assertRunningControlsStayPut(app, frames: playingFrames)

        // Buttons must also keep the parent pan from taking over. Leaving the
        // button may cancel its tap; only the page position is prescribed here.
        for identifier in ["fineTempoPlus", "fineTempoMinus", "markingTempoPlus", "markingTempoMinus"] {
            dragVerticallyFromButton(app.buttons[identifier], in: app)
            waitForCrownFramesToSettle(app, frames: playingFrames)
            assertRunningControlsStayPut(app, frames: playingFrames)
        }

        transport.tap()
        XCTAssertTrue(app.staticTexts["READY TO PLAY"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["physicalAudioExportComplete"].waitForExistence(timeout: 15),
                      "Crown playback audio export did not finish after Stop; mixer PCM and metrics must be written before test teardown")
        XCTAssertTrue(app.staticTexts["physicalScrollAuditStable"].waitForExistence(timeout: 2),
                      "Actual continuous control-touch audit exceeded 0.1 pt of scroll offset or marker drift")

        // Gesture arbitration must only protect the controls: a drag beginning
        // in read-only telemetry still scrolls the instrument normally.
        let telemetry = element("instrumentTelemetry", in: app)
        XCTAssertTrue(telemetry.exists)
        XCTAssertTrue(telemetry.isHittable)
        let previousTelemetryY = telemetry.frame.minY
        let previousCrownY = fine.frame.minY
        let start = telemetry.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: 0, dy: -180))
        start.press(forDuration: 0.1, thenDragTo: end)
        XCTAssertLessThan(telemetry.frame.minY, previousTelemetryY - 20,
                          "A drag beginning in telemetry must still scroll the page")
        XCTAssertLessThan(fine.frame.minY, previousCrownY - 20)
    }

    @MainActor
    func testTempoStepperBoundaryKeepsFrame() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--physical-qa"]
        app.launch()
        XCTAssertTrue(app.buttons["controlsButton"].waitForExistence(timeout: 10))
        app.buttons["controlsButton"].tap()
        XCTAssertTrue(app.buttons["preset120"].waitForExistence(timeout: 3))
        app.buttons["preset120"].tap()

        let increment = app.buttons["tempoStepper-Increment"]
        let decrement = app.buttons["tempoStepper-Decrement"]
        XCTAssertTrue(increment.waitForExistence(timeout: 3), "The native Stepper must expose its increment action")
        XCTAssertTrue(decrement.exists, "The native Stepper must expose its decrement action")
        let originalFrame = app.tempoStepperFrameForScrollTest.frame

        // Repeatedly cross Moderato/Allegro. A changing marking or description
        // must not move the same finger target between successive presses.
        for _ in 0..<3 {
            decrement.tap()
            XCTAssertEqual(app.staticTexts["tempoValue"].label, "119 BPM")
            assertFrame(app.tempoStepperFrameForScrollTest.frame, matches: originalFrame, context: "Stepper at 119 BPM")
            increment.tap()
            XCTAssertEqual(app.staticTexts["tempoValue"].label, "120 BPM")
            assertFrame(app.tempoStepperFrameForScrollTest.frame, matches: originalFrame, context: "Stepper at 120 BPM")
        }

        dragVerticallyFromButton(increment, in: app)
        XCTAssertTrue(app.wait(for: \.tempoStepperFrameForScrollTest,
                               toEqual: ControlFrameComparison(frame: originalFrame), timeout: 2),
                      "Dragging from native Stepper plus must keep its frame in place")
        assertFrame(app.tempoStepperFrameForScrollTest.frame, matches: originalFrame,
                    context: "Stepper after plus-button drag")
    }

    @MainActor
    func testHeldTempoStepperDoesNotScrollDuringPlayback() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--physical-qa"]
        app.launch()
        let transport = app.buttons["transportButton"]
        XCTAssertTrue(transport.waitForExistence(timeout: 10))
        let title = app.staticTexts["Metro Station"]
        XCTAssertTrue(title.waitForExistence(timeout: 3), "The renamed app must display Metro Station")
        XCTAssertTrue(title.isHittable, "Metro Station must be visible on the instrument screen")
        transport.tap()
        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].waitForExistence(timeout: 5))
        let increment = app.buttons["mainTempoStepper-Increment"]
        let decrement = app.buttons["mainTempoStepper-Decrement"]
        XCTAssertTrue(increment.waitForExistence(timeout: 3))
        XCTAssertTrue(decrement.exists)
        let gauge = element("mainTempoGauge", in: app)
        XCTAssertTrue(gauge.waitForExistence(timeout: 3))
        let originalGaugeFrame = gauge.frame
        assertGaugeVisible(gauge, in: app, matching: originalGaugeFrame)
        XCTAssertEqual(try tempoBPM(in: app, identifier: "mainTempoValue"), 120)
        for identifier in ["metroStationWavePill", "metroStationSpectrumPill"] {
            let pill = element(identifier, in: app)
            XCTAssertTrue(pill.waitForExistence(timeout: 3), "Missing main-screen \(identifier)")
            XCTAssertTrue(pill.isHittable, "\(identifier) must remain visible alongside the playing gauge")
        }
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Metro Station main gauge and signal pills"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        decrement.tap()
        XCTAssertEqual(try tempoBPM(in: app, identifier: "mainTempoValue"), 119)
        let originalFrame = app.mainTempoStepperFrameForScrollTest.frame

        try holdStepper(increment, direction: 1, app: app, originalFrame: originalFrame,
                        gauge: gauge, originalGaugeFrame: originalGaugeFrame)
        try holdStepper(decrement, direction: -1, app: app, originalFrame: originalFrame,
                        gauge: gauge, originalGaugeFrame: originalGaugeFrame)

        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].waitForExistence(timeout: 5),
                      "Playback must survive both held tempo adjustments")
        XCTAssertTrue(transport.label.contains("Stop clock"))
        XCTAssertFalse(element("engineError", in: app).exists)
        transport.tap()
        XCTAssertTrue(app.staticTexts["READY TO PLAY"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["physicalAudioExportComplete"].waitForExistence(timeout: 15),
                      "Held Stepper audio export did not finish after Stop; mixer PCM and metrics must be written before test teardown")
        XCTAssertTrue(app.staticTexts["physicalScrollAuditStable"].waitForExistence(timeout: 2),
                      "Actual continuous control-touch audit exceeded 0.1 pt of scroll offset or marker drift")
    }

    @MainActor
    func testMainTempoStepperEdgeTouchesKeepGaugeVisibleDuringPlayback() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--physical-qa"]
        app.launch()
        let transport = app.buttons["transportButton"]
        XCTAssertTrue(transport.waitForExistence(timeout: 10))
        transport.tap()
        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].waitForExistence(timeout: 5))

        let increment = app.buttons["mainTempoStepper-Increment"]
        let decrement = app.buttons["mainTempoStepper-Decrement"]
        XCTAssertTrue(increment.waitForExistence(timeout: 3))
        XCTAssertTrue(decrement.exists)
        XCTAssertTrue(increment.isHittable)
        XCTAssertTrue(decrement.isHittable)
        let gauge = element("mainTempoGauge", in: app)
        XCTAssertTrue(gauge.waitForExistence(timeout: 3))
        let originalGaugeFrame = gauge.frame
        let originalFrame = app.mainTempoStepperFrameForScrollTest.frame
        let originalButtons = ["mainTempoStepper-Increment": increment.frame,
                               "mainTempoStepper-Decrement": decrement.frame]
        assertGaugeVisible(gauge, in: app, matching: originalGaugeFrame)
        XCTAssertEqual(try tempoBPM(in: app, identifier: "mainTempoValue"), 120)

        let edges: [(identifier: String, direction: Int, y: CGFloat, travel: CGFloat)] = [
            ("mainTempoStepper-Increment", 1, 0.1, -80),
            ("mainTempoStepper-Increment", 1, 0.9, 80),
            ("mainTempoStepper-Decrement", -1, 0.1, -80),
            ("mainTempoStepper-Decrement", -1, 0.9, 80)
        ]
        for edge in edges {
            let button = app.buttons[edge.identifier]
            let beforeBPM = try tempoBPM(in: app, identifier: "mainTempoValue")
            let start = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: edge.y))
            start.tap()
            XCTAssertEqual(try tempoBPM(in: app, identifier: "mainTempoValue"), beforeBPM + edge.direction,
                           "Main native Stepper edge at y=\(edge.y) must perform exactly one whole BPM step")
            assertMainStepperAndGauge(app, stepperFrame: originalFrame, buttons: originalButtons,
                                      gauge: gauge, gaugeFrame: originalGaugeFrame)

            let endY = button.frame.minY + button.frame.height * edge.y + edge.travel
            XCTAssertGreaterThan(endY, app.frame.minY + 32)
            XCTAssertLessThan(endY, app.frame.maxY - 32)
            let dragStart = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: edge.y))
            dragStart.press(forDuration: 0.05,
                            thenDragTo: dragStart.withOffset(CGVector(dx: 0, dy: edge.travel)))
            guard increment.exists, decrement.exists, gauge.exists else {
                XCTFail("Main Stepper edge drag removed the native actions or gauge")
                return
            }
            XCTAssertTrue(app.wait(for: \.mainTempoStepperFrameForScrollTest,
                                   toEqual: ControlFrameComparison(frame: originalFrame), timeout: 2),
                          "A drag beginning on the main native Stepper edge must not scroll the instrument")
            assertMainStepperAndGauge(app, stepperFrame: originalFrame, buttons: originalButtons,
                                      gauge: gauge, gaugeFrame: originalGaugeFrame)
        }

        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].waitForExistence(timeout: 5))
        XCTAssertTrue(transport.label.contains("Stop clock"))
        XCTAssertFalse(element("engineError", in: app).exists)
        transport.tap()
        XCTAssertTrue(app.staticTexts["READY TO PLAY"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["physicalAudioExportComplete"].waitForExistence(timeout: 15),
                      "Main Stepper edge audio export must finish before test teardown")
        XCTAssertTrue(app.staticTexts["physicalScrollAuditStable"].waitForExistence(timeout: 2),
                      "Actual continuous main-Stepper touch audit exceeded 0.1 pt of scroll offset or marker drift")
    }

    @MainActor
    func testPillInteriorResponseHasStableBorders() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--pill-visual-qa"]
        app.launch()
        let transport = app.buttons["transportButton"]
        XCTAssertTrue(transport.waitForExistence(timeout: 10))
        transport.tap()
        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].waitForExistence(timeout: 5))

        // The DEBUG hook freezes only the pills from an actual rendered onset.
        // XCTest never invents tick age or tries to race the display's attack.
        let peakReady = app.staticTexts["pillVisualPeakReady"]
        XCTAssertTrue(peakReady.waitForExistence(timeout: 15),
                      "The pills must capture their display peak from a live audio tick")
        let identifiers = ["metroStationWavePill", "metroStationSpectrumPill", "mainTempoGauge",
                           "mainTempoStepper-Increment", "mainTempoStepper-Decrement"]
        var peakFrames: [String: CGRect] = [:]
        for identifier in identifiers {
            let control = element(identifier, in: app)
            XCTAssertTrue(control.waitForExistence(timeout: 3), "Missing \(identifier)")
            XCTAssertTrue(control.isHittable, "\(identifier) must remain visible at the peak")
            peakFrames[identifier] = control.frame
        }
        peakFrames["mainTempoStepper"] = app.mainTempoStepperFrameForScrollTest.frame
        let gauge = element("mainTempoGauge", in: app)
        let gaugeFrame = try XCTUnwrap(peakFrames["mainTempoGauge"])
        assertGaugeVisible(gauge, in: app, matching: gaugeFrame)
        let peak = app.screenshot()
        let peakAttachment = XCTAttachment(screenshot: peak)
        peakAttachment.name = "Pill peak from live audio onset"
        peakAttachment.lifetime = .keepAlways
        add(peakAttachment)
        let peakState = peakReady.label

        let showQuiet = app.buttons["pillVisualShowQuiet"]
        XCTAssertTrue(showQuiet.waitForExistence(timeout: 3))
        XCTAssertTrue(showQuiet.isHittable, "The DEBUG quiet-sample action needs a visible native touch target")
        showQuiet.tap()
        let quietReady = app.staticTexts["pillVisualQuietReady"]
        XCTAssertTrue(quietReady.waitForExistence(timeout: 15),
                      "The pills must capture a true quiet state after the finite visual response")
        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].exists,
                      "Capturing the quiet pill sample must preserve actual playback")
        XCTAssertTrue(transport.label.contains("Stop clock"))

        var quietFrames: [String: CGRect] = [:]
        for identifier in identifiers {
            let control = element(identifier, in: app)
            XCTAssertTrue(control.exists)
            XCTAssertTrue(control.isHittable, "\(identifier) must remain visible in the quiet sample")
            quietFrames[identifier] = control.frame
            assertFrame(control.frame, matches: try XCTUnwrap(peakFrames[identifier]),
                        context: "\(identifier) between peak and quiet", accuracy: 0.1)
        }
        quietFrames["mainTempoStepper"] = app.mainTempoStepperFrameForScrollTest.frame
        assertFrame(app.mainTempoStepperFrameForScrollTest.frame,
                    matches: try XCTUnwrap(peakFrames["mainTempoStepper"]),
                    context: "Main Stepper between peak and quiet", accuracy: 0.1)
        assertGaugeVisible(gauge, in: app, matching: gaugeFrame)
        let quiet = app.screenshot()
        let quietAttachment = XCTAttachment(screenshot: quiet)
        quietAttachment.name = "Pill quiet after live finite response"
        quietAttachment.lifetime = .keepAlways
        add(quietAttachment)

        // These are real native pixels and screen-coordinate crops for an
        // independent outline/interior comparison after result extraction.
        // No view-computed "visual pass" replaces the pixel evidence.
        let metadata: [String: Any] = [
            "coordinateUnits": "screen points",
            "screenFrame": rectangleMetadata(app.frame),
            "peak": try screenshotMetadata(peak, attachmentName: peakAttachment.name,
                                            capturedState: peakState, frames: peakFrames),
            "quiet": try screenshotMetadata(quiet, attachmentName: quietAttachment.name,
                                             capturedState: quietReady.label, frames: quietFrames)
        ]
        let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        let report = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        report.name = "Native pill peak and quiet crop metadata"
        report.lifetime = .keepAlways
        add(report)

        XCTAssertFalse(element("engineError", in: app).exists)
        transport.tap()
        XCTAssertTrue(app.staticTexts["READY TO PLAY"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testSyntheticTiltRefractionKeepsReadoutAndControlsStill() throws {
        try captureTiltRefraction(source: "synthetic", launchArgument: "--tilt-refraction-qa",
                                  poseTimeout: 15)
    }

    /// User-assisted physical-device case. The user must tilt the phone in both
    /// directions; this never substitutes an injected vector for the sensor.
    @MainActor
    func testLiveGravityRefractionKeepsReadoutAndControlsStill() throws {
        try captureTiltRefraction(source: "actualGravity", launchArgument: "--tilt-refraction-live-qa",
                                  poseTimeout: 90)
    }

    @MainActor
    private func captureTiltRefraction(source: String, launchArgument: String,
                                       poseTimeout: TimeInterval) throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", launchArgument]
        app.launch()
        let transport = app.buttons["transportButton"]
        XCTAssertTrue(transport.waitForExistence(timeout: 10))
        transport.tap()
        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].waitForExistence(timeout: 5))
        XCTAssertEqual(try tempoBPM(in: app, identifier: "mainTempoValue"), 120)

        let positiveReady = app.staticTexts["tiltRefractionPositiveReady"]
        XCTAssertTrue(positiveReady.waitForExistence(timeout: poseTimeout),
                      source == "actualGravity"
                        ? "User-assisted test requires actual filtered phone tilt x >= 0.35"
                        : "Injected positive normalized tilt must render with a held live beat")
        let positiveState = positiveReady.label
        let positiveFields = readinessFields(positiveState)
        XCTAssertEqual(positiveFields["source"], source,
                       "Injected rendering and actual sensor evidence must remain distinct")
        let positiveX = try XCTUnwrap(Double(try XCTUnwrap(positiveFields["x"])))
        let positiveY = try XCTUnwrap(Double(try XCTUnwrap(positiveFields["y"])))
        if source == "actualGravity" {
            XCTAssertGreaterThanOrEqual(positiveX, 0.35)
        } else {
            XCTAssertEqual(positiveX, 0.70, accuracy: 0.000001)
            XCTAssertEqual(positiveY, 0.35, accuracy: 0.000001)
        }

        // The gauge exposes the readout as one combined accessibility element.
        // Native text stillness is checked from its geometric screenshot crop.
        let identifiers = ["mainTempoGauge", "mainTempoStepper-Increment",
                           "mainTempoStepper-Decrement", "metroStationWavePill", "metroStationSpectrumPill"]
        var positiveFrames: [String: CGRect] = [:]
        for identifier in identifiers {
            let control = element(identifier, in: app)
            XCTAssertTrue(control.waitForExistence(timeout: 3), "Missing \(identifier)")
            XCTAssertTrue(control.isHittable, "\(identifier) must stay visible during tilt")
            positiveFrames[identifier] = control.frame
        }
        positiveFrames["mainTempoStepper"] = app.mainTempoStepperFrameForScrollTest.frame
        let gauge = element("mainTempoGauge", in: app)
        let gaugeFrame = try XCTUnwrap(positiveFrames["mainTempoGauge"])
        assertGaugeVisible(gauge, in: app, matching: gaugeFrame)
        let positiveValue = try XCTUnwrap(gauge.value as? String)
        let description = source == "actualGravity" ? "Actual gravity tilt" : "Synthetic injected tilt"
        let positive = app.screenshot()
        let positiveAttachment = XCTAttachment(screenshot: positive)
        positiveAttachment.name = "\(description) positive from held live beat"
        positiveAttachment.lifetime = .keepAlways
        add(positiveAttachment)

        let showNegative = app.buttons["tiltRefractionShowNegative"]
        XCTAssertTrue(showNegative.waitForExistence(timeout: 3))
        XCTAssertTrue(showNegative.isHittable, "Tilt QA needs a visible native sample action")
        showNegative.tap()
        let negativeReady = app.staticTexts["tiltRefractionNegativeReady"]
        XCTAssertTrue(negativeReady.waitForExistence(timeout: poseTimeout),
                      source == "actualGravity"
                        ? "User-assisted test requires actual filtered phone tilt x <= -0.35"
                        : "Injected negative normalized tilt must render from the same held beat")
        let negativeState = negativeReady.label
        let negativeFields = readinessFields(negativeState)
        XCTAssertEqual(negativeFields["source"], source)
        let negativeX = try XCTUnwrap(Double(try XCTUnwrap(negativeFields["x"])))
        let negativeY = try XCTUnwrap(Double(try XCTUnwrap(negativeFields["y"])))
        if source == "actualGravity" {
            XCTAssertLessThanOrEqual(negativeX, -0.35)
        } else {
            XCTAssertEqual(negativeX, -0.70, accuracy: 0.000001)
            XCTAssertEqual(negativeY, -0.35, accuracy: 0.000001)
        }
        // Holding the same actual beat and radius removes ticker/spring motion
        // as explanations for a changed native refraction image.
        for field in ["phase", "radiusScale", "bpm"] {
            let first = try XCTUnwrap(Double(try XCTUnwrap(positiveFields[field])), "Missing \(field)")
            let second = try XCTUnwrap(Double(try XCTUnwrap(negativeFields[field])), "Missing \(field)")
            XCTAssertEqual(first, second, accuracy: 0.000000000001,
                           "Tilt comparison must preserve the held \(field)")
        }
        let heldSnapshot = try XCTUnwrap(positiveFields["heldSnapshot"])
        XCTAssertFalse(heldSnapshot.isEmpty)
        XCTAssertEqual(negativeFields["heldSnapshot"], heldSnapshot,
                       "Both poses must use one shared captured snapshot")
        let positiveCount = try XCTUnwrap(Int(try XCTUnwrap(positiveFields["sampleCount"])))
        let negativeCount = try XCTUnwrap(Int(try XCTUnwrap(negativeFields["sampleCount"])))
        let positiveTimestamp = try XCTUnwrap(Double(try XCTUnwrap(positiveFields["sensorTimestamp"])))
        let negativeTimestamp = try XCTUnwrap(Double(try XCTUnwrap(negativeFields["sensorTimestamp"])))
        if source == "actualGravity" {
            XCTAssertGreaterThan(positiveCount, 5, "Actual gravity needs multiple CoreMotion callbacks")
            XCTAssertGreaterThan(negativeCount, positiveCount)
            XCTAssertGreaterThan(positiveTimestamp, 0)
            XCTAssertGreaterThan(negativeTimestamp, positiveTimestamp,
                                 "Opposite actual poses must come from newer sensor data")
            for fields in [positiveFields, negativeFields] {
                let gravity = try ["gravityX", "gravityY", "gravityZ"].map { field in
                    try XCTUnwrap(Double(try XCTUnwrap(fields[field])), "Missing actual \(field)")
                }
                XCTAssertTrue(gravity.allSatisfy(\.isFinite))
                let magnitude = gravity.reduce(0) { $0 + $1 * $1 }.squareRoot()
                XCTAssertGreaterThanOrEqual(magnitude, 0.95)
                XCTAssertLessThanOrEqual(magnitude, 1.05)
            }
        } else {
            XCTAssertEqual(positiveCount, 0)
            XCTAssertEqual(negativeCount, 0)
            XCTAssertEqual(positiveTimestamp, 0)
            XCTAssertEqual(negativeTimestamp, 0,
                           "Injected vectors must not carry fabricated sensor evidence")
        }
        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].exists)
        XCTAssertTrue(transport.label.contains("Stop clock"))
        XCTAssertEqual(try tempoBPM(in: app, identifier: "mainTempoValue"), 120)

        var negativeFrames: [String: CGRect] = [:]
        for identifier in identifiers {
            let control = element(identifier, in: app)
            XCTAssertTrue(control.exists)
            XCTAssertTrue(control.isHittable)
            negativeFrames[identifier] = control.frame
            assertFrame(control.frame, matches: try XCTUnwrap(positiveFrames[identifier]),
                        context: "\(identifier) across opposite tilt samples", accuracy: 0.1)
        }
        negativeFrames["mainTempoStepper"] = app.mainTempoStepperFrameForScrollTest.frame
        assertFrame(app.mainTempoStepperFrameForScrollTest.frame,
                    matches: try XCTUnwrap(positiveFrames["mainTempoStepper"]),
                    context: "Main Stepper across opposite tilt samples", accuracy: 0.1)
        assertGaugeVisible(gauge, in: app, matching: gaugeFrame)
        XCTAssertEqual(try XCTUnwrap(gauge.value as? String), positiveValue)
        let negative = app.screenshot()
        let negativeAttachment = XCTAttachment(screenshot: negative)
        negativeAttachment.name = "\(description) negative from held live beat"
        negativeAttachment.lifetime = .keepAlways
        add(negativeAttachment)

        let textCrop = CGRect(x: gaugeFrame.minX + gaugeFrame.width * 0.15,
                              y: gaugeFrame.minY + gaugeFrame.height * 0.37,
                              width: gaugeFrame.width * 0.70, height: gaugeFrame.height * 0.43)
        let metadata: [String: Any] = [
            "source": source,
            "sensorClaim": source == "actualGravity"
                ? "User-assisted actual filtered gravity captures requested"
                : "Injected normalized tilt tests rendering only; no physical sensor claim",
            "comparisonPolicy": "One held live beat/ticker snapshot and glass radius; opposite tilt samples",
            "coordinateUnits": "screen points",
            "screenFrame": rectangleMetadata(app.frame),
            "selectedBPM": 120,
            "centralTempoTextInspectionRegion": rectangleMetadata(textCrop),
            "centralTempoTextInspectionRegionKind": "Geometric crop, not accessibility text bounds",
            "positiveGaugeAccessibilityValue": positiveValue,
            "negativeGaugeAccessibilityValue": try XCTUnwrap(gauge.value as? String),
            "positive": try screenshotMetadata(positive, attachmentName: positiveAttachment.name,
                                                capturedState: positiveState, frames: positiveFrames),
            "negative": try screenshotMetadata(negative, attachmentName: negativeAttachment.name,
                                                capturedState: negativeState, frames: negativeFrames)
        ]
        let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        let report = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        report.name = "Native \(source) tilt refraction crop metadata"
        report.lifetime = .keepAlways
        add(report)

        XCTAssertFalse(element("engineError", in: app).exists)
        transport.tap()
        XCTAssertTrue(app.staticTexts["READY TO PLAY"].waitForExistence(timeout: 3))
    }

    private func readinessFields(_ label: String) -> [String: String] {
        var fields: [String: String] = [:]
        for component in label.split(separator: ";") {
            let pair = component.split(separator: "=", maxSplits: 1)
            guard pair.count == 2 else { continue }
            fields[String(pair[0]).trimmingCharacters(in: .whitespaces)] =
                String(pair[1]).trimmingCharacters(in: .whitespaces)
        }
        return fields
    }

    @MainActor
    func testGlassDialResponseKeepsInstrumentFrames() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--glass-dial-qa"]
        app.launch()
        let transport = app.buttons["transportButton"]
        XCTAssertTrue(transport.waitForExistence(timeout: 10))
        transport.tap()
        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].waitForExistence(timeout: 5))
        XCTAssertEqual(try tempoBPM(in: app, identifier: "mainTempoValue"), 120)

        // The DEBUG hook holds only the glass layer at a phase sampled from
        // actual playback. The gauge, pills, sound and haptics remain live.
        let expandedReady = app.staticTexts["glassDialExpandedReady"]
        XCTAssertTrue(expandedReady.waitForExistence(timeout: 15),
                      "The glass dial must capture its expanded phase from an actual running beat")
        let identifiers = ["metroStationWavePill", "metroStationSpectrumPill", "mainTempoGauge",
                           "mainTempoStepper-Increment", "mainTempoStepper-Decrement"]
        var expandedFrames: [String: CGRect] = [:]
        for identifier in identifiers {
            let control = element(identifier, in: app)
            XCTAssertTrue(control.waitForExistence(timeout: 3), "Missing \(identifier)")
            XCTAssertTrue(control.isHittable, "\(identifier) must remain visible with expanded glass")
            expandedFrames[identifier] = control.frame
        }
        expandedFrames["mainTempoStepper"] = app.mainTempoStepperFrameForScrollTest.frame
        let gauge = element("mainTempoGauge", in: app)
        let gaugeFrame = try XCTUnwrap(expandedFrames["mainTempoGauge"])
        assertGaugeVisible(gauge, in: app, matching: gaugeFrame)
        let expandedState = expandedReady.label
        let expandedGaugeValue = try XCTUnwrap(gauge.value as? String,
                                               "The gauge must retain its readable tempo value")
        let expanded = app.screenshot()
        let expandedAttachment = XCTAttachment(screenshot: expanded)
        expandedAttachment.name = "Glass dial expanded from live beat"
        expandedAttachment.lifetime = .keepAlways
        add(expandedAttachment)

        let showCompressed = app.buttons["glassDialShowCompressed"]
        XCTAssertTrue(showCompressed.waitForExistence(timeout: 3))
        XCTAssertTrue(showCompressed.isHittable, "The DEBUG glass-sample action needs a visible native touch target")
        showCompressed.tap()
        let compressedReady = app.staticTexts["glassDialCompressedReady"]
        XCTAssertTrue(compressedReady.waitForExistence(timeout: 15),
                      "The glass dial must capture its compressed phase from an actual running beat")
        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].exists,
                      "Sampling the glass phase must preserve playback")
        XCTAssertTrue(transport.label.contains("Stop clock"))
        XCTAssertEqual(try tempoBPM(in: app, identifier: "mainTempoValue"), 120)

        var compressedFrames: [String: CGRect] = [:]
        for identifier in identifiers {
            let control = element(identifier, in: app)
            XCTAssertTrue(control.exists)
            XCTAssertTrue(control.isHittable, "\(identifier) must remain visible with compressed glass")
            compressedFrames[identifier] = control.frame
            assertFrame(control.frame, matches: try XCTUnwrap(expandedFrames[identifier]),
                        context: "\(identifier) between glass samples", accuracy: 0.1)
        }
        compressedFrames["mainTempoStepper"] = app.mainTempoStepperFrameForScrollTest.frame
        assertFrame(app.mainTempoStepperFrameForScrollTest.frame,
                    matches: try XCTUnwrap(expandedFrames["mainTempoStepper"]),
                    context: "Main Stepper between glass samples", accuracy: 0.1)
        assertGaugeVisible(gauge, in: app, matching: gaugeFrame)
        let compressedState = compressedReady.label
        let compressedGaugeValue = try XCTUnwrap(gauge.value as? String)
        XCTAssertEqual(compressedGaugeValue, expandedGaugeValue,
                       "The decorative glass must preserve the gauge's tempo accessibility value")
        let compressed = app.screenshot()
        let compressedAttachment = XCTAttachment(screenshot: compressed)
        compressedAttachment.name = "Glass dial compressed from live beat"
        compressedAttachment.lifetime = .keepAlways
        add(compressedAttachment)

        // The gauge deliberately merges its text into one accessibility node.
        // This crop is a geometric inspection region, not measured text bounds.
        let textCrop = CGRect(x: gaugeFrame.minX + gaugeFrame.width * 0.15,
                              y: gaugeFrame.minY + gaugeFrame.height * 0.37,
                              width: gaugeFrame.width * 0.70, height: gaugeFrame.height * 0.43)
        let metadata: [String: Any] = [
            "coordinateUnits": "screen points",
            "screenFrame": rectangleMetadata(app.frame),
            "selectedBPM": 120,
            "samplePolicy": "Only the glass layer holds a beat phase sampled from live playback; other instrument motion remains live",
            "centralTempoTextInspectionRegion": rectangleMetadata(textCrop),
            "centralTempoTextInspectionRegionKind": "Geometric crop within the measured gauge, not accessibility text bounds",
            "expandedGaugeAccessibilityValue": expandedGaugeValue,
            "compressedGaugeAccessibilityValue": compressedGaugeValue,
            "expanded": try screenshotMetadata(expanded, attachmentName: expandedAttachment.name,
                                                capturedState: expandedState, frames: expandedFrames),
            "compressed": try screenshotMetadata(compressed, attachmentName: compressedAttachment.name,
                                                  capturedState: compressedState, frames: compressedFrames)
        ]
        let data = try JSONSerialization.data(withJSONObject: metadata, options: [.prettyPrinted, .sortedKeys])
        let report = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        report.name = "Native glass dial crop metadata"
        report.lifetime = .keepAlways
        add(report)

        XCTAssertFalse(element("engineError", in: app).exists)
        transport.tap()
        XCTAssertTrue(app.staticTexts["READY TO PLAY"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testTempoStepperEdgeTouchesDoNotScrollDuringPlayback() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--physical-qa"]
        app.launch()
        let transport = app.buttons["transportButton"]
        XCTAssertTrue(transport.waitForExistence(timeout: 10))
        transport.tap()
        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].waitForExistence(timeout: 5))
        app.buttons["controlsButton"].tap()
        XCTAssertTrue(app.buttons["preset120"].waitForExistence(timeout: 3))
        app.buttons["preset120"].tap()

        let increment = app.buttons["tempoStepper-Increment"]
        let decrement = app.buttons["tempoStepper-Decrement"]
        XCTAssertTrue(increment.waitForExistence(timeout: 3))
        XCTAssertTrue(decrement.exists)
        let originalFrame = app.tempoStepperFrameForScrollTest.frame
        let originalButtons = ["tempoStepper-Increment": increment.frame,
                               "tempoStepper-Decrement": decrement.frame]
        let edges: [(identifier: String, direction: Int, y: CGFloat, travel: CGFloat)] = [
            ("tempoStepper-Increment", 1, 0.1, -80),
            ("tempoStepper-Increment", 1, 0.9, 80),
            ("tempoStepper-Decrement", -1, 0.1, -80),
            ("tempoStepper-Decrement", -1, 0.9, 80)
        ]

        for edge in edges {
            let button = app.buttons[edge.identifier]
            let beforeBPM = try tempoBPM(in: app)
            let tap = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: edge.y))
            tap.tap()
            XCTAssertEqual(try tempoBPM(in: app), beforeBPM + edge.direction,
                           "The native \(edge.identifier) edge at y=\(edge.y) must perform exactly one BPM step")
            assertFrame(app.tempoStepperFrameForScrollTest.frame, matches: originalFrame,
                        context: "Stepper after edge tap at y=\(edge.y)")
            for (identifier, frame) in originalButtons {
                assertFrame(app.buttons[identifier].frame, matches: frame,
                            context: "\(identifier) after edge tap")
            }

            // Move away from the button's top/bottom edge. This deliberately
            // begins outside the old 20-point boundary but inside the native
            // 32-point button; the enclosing page must not acquire its pan.
            let start = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: edge.y))
            let endY = button.frame.minY + button.frame.height * edge.y + edge.travel
            XCTAssertGreaterThan(endY, app.frame.minY + 32)
            XCTAssertLessThan(endY, app.frame.maxY - 32)
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: edge.travel)))
            guard app.buttons["controlsDone"].exists,
                  app.buttons["tempoStepper-Increment"].exists,
                  app.buttons["tempoStepper-Decrement"].exists else {
                XCTFail("Stepper edge drag at y=\(edge.y) dismissed the Controls panel or removed its native Stepper actions")
                return
            }
            XCTAssertTrue(app.wait(for: \.tempoStepperFrameForScrollTest,
                                   toEqual: ControlFrameComparison(frame: originalFrame), timeout: 2),
                          "Dragging from native \(edge.identifier) edge at y=\(edge.y) must not scroll the page")
            assertFrame(app.tempoStepperFrameForScrollTest.frame, matches: originalFrame,
                        context: "Stepper after edge drag at y=\(edge.y)")
            for (identifier, frame) in originalButtons {
                assertFrame(app.buttons[identifier].frame, matches: frame,
                            context: "\(identifier) after edge drag")
            }
        }

        app.buttons["controlsDone"].tap()
        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].waitForExistence(timeout: 5),
                      "Playback must survive all eight Stepper edge contacts")
        XCTAssertTrue(transport.label.contains("Stop clock"))
        XCTAssertFalse(element("engineError", in: app).exists)
        transport.tap()
        XCTAssertTrue(app.staticTexts["READY TO PLAY"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["physicalAudioExportComplete"].waitForExistence(timeout: 15),
                      "Stepper edge-test audio export did not finish after Stop; mixer PCM and metrics must be written before test teardown")
        XCTAssertTrue(app.staticTexts["physicalScrollAuditStable"].waitForExistence(timeout: 2),
                      "Actual continuous control-touch audit exceeded 0.1 pt of scroll offset or marker drift")
    }

    @MainActor
    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func crownBPM(_ crown: XCUIElement) throws -> Int {
        let value = try XCTUnwrap(crown.value as? String, "The fine crown must expose its BPM value")
        return try XCTUnwrap(value.split(separator: " ").first.flatMap { Int($0) },
                             "The fine crown value must begin with a whole BPM")
    }

    @MainActor
    private func crownMarking(_ crown: XCUIElement) throws -> String {
        let value = try XCTUnwrap(crown.value as? String)
        return try XCTUnwrap(value.split(separator: ",").first.map(String.init),
                             "The marking crown must expose its current tempo band")
    }

    @MainActor
    private func tempoBPM(in app: XCUIApplication, identifier: String = "tempoValue") throws -> Int {
        let label = app.staticTexts[identifier]
        // Native Stepper can merge its label into the two action elements.
        // The main gauge independently exposes the same selected whole BPM.
        let value: String
        if identifier == "mainTempoValue", !label.exists {
            value = try XCTUnwrap(element("mainTempoGauge", in: app).value as? String,
                                  "The main tempo label or gauge must expose its BPM")
        } else {
            value = label.label
        }
        return try XCTUnwrap(value.split(separator: " ").first.flatMap { Int($0) },
                             "Tempo must remain a whole BPM during adjustment")
    }

    @MainActor
    private func holdStepper(_ button: XCUIElement, direction: Int, app: XCUIApplication,
                             originalFrame: CGRect, gauge: XCUIElement,
                             originalGaugeFrame: CGRect) throws {
        let beforeBPM = try tempoBPM(in: app, identifier: "mainTempoValue")
        let originalButtonFrame = button.frame
        XCTAssertTrue(button.isHittable)
        assertFrame(app.mainTempoStepperFrameForScrollTest.frame, matches: originalFrame,
                    context: "Stepper before hold")
        assertGaugeVisible(gauge, in: app, matching: originalGaugeFrame)
        let started = ProcessInfo.processInfo.systemUptime
        // The app-side --physical-qa audit records frames throughout the held
        // touch. XCTest's synchronous native press only queries before/after.
        button.press(forDuration: 2)
        let finished = ProcessInfo.processInfo.systemUptime
        let afterBPM = try tempoBPM(in: app, identifier: "mainTempoValue")
        let repeatedSteps = (afterBPM - beforeBPM) * direction
        XCTAssertGreaterThan(repeatedSteps, 1, "A two-second native Stepper hold must repeat whole BPM changes")

        let report = (["phase,secondsFromPressCall,bpm,buttonY,stepperY,gaugeY",
                       "before,0,\(beforeBPM),\(originalButtonFrame.minY),\(originalFrame.minY),\(originalGaugeFrame.minY)",
                       "after,\(finished - started),\(afterBPM),\(button.frame.minY),\(app.mainTempoStepperFrameForScrollTest.frame.minY),\(gauge.frame.minY)"])
            .joined(separator: "\n")
        let attachment = XCTAttachment(string: report)
        attachment.name = direction > 0 ? "Stepper increment hold frames and BPM" : "Stepper decrement hold frames and BPM"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertTrue(app.wait(for: \.mainTempoStepperFrameForScrollTest,
                               toEqual: ControlFrameComparison(frame: originalFrame), timeout: 2))
        assertFrame(button.frame, matches: originalButtonFrame, context: "Held Stepper button after hold")
        assertFrame(app.mainTempoStepperFrameForScrollTest.frame, matches: originalFrame, context: "Stepper after hold")
        assertGaugeVisible(gauge, in: app, matching: originalGaugeFrame)
    }

    @MainActor
    private func assertMainStepperAndGauge(_ app: XCUIApplication, stepperFrame: CGRect,
                                          buttons: [String: CGRect], gauge: XCUIElement,
                                          gaugeFrame: CGRect) {
        assertFrame(app.mainTempoStepperFrameForScrollTest.frame, matches: stepperFrame,
                    context: "Main Stepper after contact")
        for (identifier, frame) in buttons {
            let button = app.buttons[identifier]
            XCTAssertTrue(button.exists)
            XCTAssertTrue(button.isHittable)
            assertFrame(button.frame, matches: frame, context: "\(identifier) after contact")
        }
        assertGaugeVisible(gauge, in: app, matching: gaugeFrame)
    }

    @MainActor
    private func assertGaugeVisible(_ gauge: XCUIElement, in app: XCUIApplication, matching original: CGRect) {
        XCTAssertTrue(gauge.exists, "The main gauge must remain present during tempo adjustments")
        XCTAssertTrue(gauge.isHittable, "The main gauge must remain visible during tempo adjustments")
        let frame = gauge.frame
        XCTAssertGreaterThan(frame.width, 0)
        XCTAssertGreaterThan(frame.height, 0)
        XCTAssertGreaterThanOrEqual(frame.minX, app.frame.minX - 0.1)
        XCTAssertGreaterThanOrEqual(frame.minY, app.frame.minY - 0.1)
        XCTAssertLessThanOrEqual(frame.maxX, app.frame.maxX + 0.1)
        XCTAssertLessThanOrEqual(frame.maxY, app.frame.maxY + 0.1)
        XCTAssertEqual(frame.minX, original.minX, accuracy: 0.1, "Gauge moved horizontally")
        XCTAssertEqual(frame.minY, original.minY, accuracy: 0.1, "Gauge moved vertically")
        XCTAssertEqual(frame.width, original.width, accuracy: 0.1, "Gauge changed width")
        XCTAssertEqual(frame.height, original.height, accuracy: 0.1, "Gauge changed height")
    }

    @MainActor
    private func crownFrames(in app: XCUIApplication) -> [String: CGRect] {
        let identifiers = ["fineTempoCrown", "markingTempoCrown", "fineTempoPlus",
                           "fineTempoMinus", "markingTempoPlus", "markingTempoMinus"]
        return Dictionary(uniqueKeysWithValues: identifiers.map { identifier in
            let control = element(identifier, in: app)
            XCTAssertTrue(control.exists, "Missing \(identifier)")
            XCTAssertTrue(control.isHittable, "\(identifier) must be visible before the adjustment")
            return (identifier, control.frame)
        })
    }

    @MainActor
    private func assertRunningControlsStayPut(_ app: XCUIApplication, frames: [String: CGRect]) {
        XCTAssertTrue(app.staticTexts["CLOCK RUNNING"].waitForExistence(timeout: 3))
        XCTAssertFalse(element("engineError", in: app).exists)
        assertCrownFramesStayPut(app, frames: frames)
    }

    @MainActor
    private func assertCrownFramesStayPut(_ app: XCUIApplication, frames: [String: CGRect]) {
        for (identifier, original) in frames {
            let control = element(identifier, in: app)
            XCTAssertTrue(control.exists)
            XCTAssertEqual(control.frame.minY, original.minY, accuracy: 1,
                           "\(identifier) moved vertically while adjusting tempo")
        }
    }

    @MainActor
    private func dragFromRim(_ crown: XCUIElement, increasing: Bool) {
        let start = crown.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        let end = crown.coordinate(withNormalizedOffset: CGVector(dx: 0.74, dy: increasing ? 0.87 : 0.13))
        start.press(forDuration: 0.1, thenDragTo: end)
    }

    @MainActor
    private func dragVerticallyFromButton(_ button: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(button.exists)
        let availableUpwardTravel = button.frame.midY - app.frame.minY - 32
        let distance = min(90, max(0, availableUpwardTravel))
        XCTAssertGreaterThanOrEqual(distance, 40, "The drag must stay within the visible viewport")
        let start = button.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)))
    }

    @MainActor
    private func waitForCrownFramesToSettle(_ app: XCUIApplication, frames: [String: CGRect]) {
        for (identifier, original) in frames {
            let control = element(identifier, in: app)
            XCTAssertTrue(control.wait(for: \.verticalFrameForScrollTest,
                                       toEqual: ControlFrameComparison(frame: original, verticalOnly: true),
                                       timeout: 2),
                          "A vertical button drag must leave \(identifier) in place")
        }
    }

    private func rectangleMetadata(_ frame: CGRect) -> [String: Double] {
        ["x": Double(frame.minX), "y": Double(frame.minY),
         "width": Double(frame.width), "height": Double(frame.height)]
    }

    @MainActor
    private func screenshotMetadata(_ screenshot: XCUIScreenshot, attachmentName: String?,
                                    capturedState: String, frames: [String: CGRect]) throws -> [String: Any] {
        let image = try XCTUnwrap(screenshot.image.cgImage, "Native screenshot pixels must be available")
        return ["attachmentName": attachmentName ?? "", "capturedState": capturedState,
                "nativePixelWidth": image.width, "nativePixelHeight": image.height,
                "imageScale": Double(screenshot.image.scale),
                "frames": frames.mapValues(rectangleMetadata)]
    }

    private func assertFrame(_ frame: CGRect, matches original: CGRect, context: String, accuracy: CGFloat = 1) {
        XCTAssertEqual(frame.minX, original.minX, accuracy: accuracy, "\(context) moved horizontally")
        XCTAssertEqual(frame.minY, original.minY, accuracy: accuracy, "\(context) moved vertically")
        XCTAssertEqual(frame.width, original.width, accuracy: accuracy, "\(context) changed width")
        XCTAssertEqual(frame.height, original.height, accuracy: accuracy, "\(context) changed height")
    }
}

/// XCTest's bounded attribute wait owns polling and MainActor access. Equality
/// deliberately applies the same one-point tolerance as the final assertions.
private struct ControlFrameComparison: Equatable {
    let frame: CGRect
    var verticalOnly = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        guard abs(lhs.frame.minY - rhs.frame.minY) <= 1 else { return false }
        return (lhs.verticalOnly && rhs.verticalOnly) ||
            (abs(lhs.frame.minX - rhs.frame.minX) <= 1 &&
             abs(lhs.frame.width - rhs.frame.width) <= 1 &&
             abs(lhs.frame.height - rhs.frame.height) <= 1)
    }
}

@MainActor
private extension XCUIElement {
    var verticalFrameForScrollTest: ControlFrameComparison {
        ControlFrameComparison(frame: frame, verticalOnly: true)
    }

    var tempoStepperFrameForScrollTest: ControlFrameComparison {
        let container = descendants(matching: .any).matching(identifier: "tempoStepper").firstMatch
        if container.exists { return ControlFrameComparison(frame: container.frame) }
        // Some native Stepper accessibility trees expose only their two actions.
        return ControlFrameComparison(frame: buttons["tempoStepper-Increment"].frame
            .union(buttons["tempoStepper-Decrement"].frame))
    }

    var mainTempoStepperFrameForScrollTest: ControlFrameComparison {
        let container = descendants(matching: .any).matching(identifier: "mainTempoStepper").firstMatch
        if container.exists { return ControlFrameComparison(frame: container.frame) }
        return ControlFrameComparison(frame: buttons["mainTempoStepper-Increment"].frame
            .union(buttons["mainTempoStepper-Decrement"].frame))
    }
}
