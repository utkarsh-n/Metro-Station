import Testing
@testable import MetronomeCore

@Suite("Approximate musical tempo markings")
struct TempoMarkingTests {
    @Test
    func conventionalBoundariesAreDeterministic() {
        let transitions: [(Double, TempoMarking, TempoMarking)] = [
            (60, .largo, .adagio), (76, .adagio, .andante),
            (108, .andante, .moderato), (120, .moderato, .allegro),
            (168, .allegro, .presto), (200, .presto, .prestissimo)
        ]
        for (boundary, below, at) in transitions {
            #expect(TempoMarking.forBPM(boundary.nextDown) == below)
            #expect(TempoMarking.forBPM(boundary) == at)
        }
        #expect(TempoMarking.forBPM(30) == .largo)
        #expect(TempoMarking.forBPM(240) == .prestissimo)
        #expect(TempoMarking.forBPM(.nan) == .allegro)
        #expect(TempoMarking.forBPM(-40) == .largo)
        #expect(TempoMarking.forBPM(999) == .prestissimo)
    }

    @Test
    func labelsExposeApproximateRanges() {
        for bpm in 30...240 {
            let marking = TempoMarking.forBPM(Double(bpm))
            #expect(marking.approximateRange.contains(Double(bpm)))
            #expect(!marking.name.isEmpty && !marking.character.isEmpty)
            #expect(marking.approximateRangeText.contains("approximate"))
            #expect(marking.approximateRangeText.contains("BPM"))
        }
    }
}
