import Testing

@testable import PomoDuo

@MainActor
struct HapticTriggerTests {

    @Test func initialStateHasNoEvent() {
        let trigger = HapticTrigger()
        #expect(trigger.event == nil)
        #expect(trigger.style == .impactLight)
    }

    @Test func fireStoresEvent() {
        var trigger = HapticTrigger()
        trigger.fire(.start)
        #expect(trigger.event == .start)
        #expect(trigger.style == .impactMedium)
    }

    @Test func firingDifferentEventsUpdatesStyle() {
        var trigger = HapticTrigger()
        trigger.fire(.pause)
        #expect(trigger.style == .impactSoft)

        trigger.fire(.complete)
        #expect(trigger.style == .success)
    }

    @Test func firingSameEventTwiceChangesTriggerValue() {
        var first = HapticTrigger()
        first.fire(.resume)

        var second = first
        second.fire(.resume)

        #expect(first != second)
    }

    @Test func styleMapsForEachEvent() {
        var trigger = HapticTrigger()

        trigger.fire(.start)
        #expect(trigger.style == .impactMedium)

        trigger.fire(.pause)
        #expect(trigger.style == .impactSoft)

        trigger.fire(.resume)
        #expect(trigger.style == .impactMedium)

        trigger.fire(.phaseChange)
        #expect(trigger.style == .impactHeavy)

        trigger.fire(.stop)
        #expect(trigger.style == .impactRigid)

        trigger.fire(.complete)
        #expect(trigger.style == .success)
    }
}
