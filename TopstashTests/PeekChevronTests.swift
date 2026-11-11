import Testing

@testable import Topstash

/// What a row shows on the right of its title: the age, or the chevron that toggles its peek.
@MainActor
struct PeekChevronTests {
    @Test func aRowShowsItsAgeUntilHovered() {
        #expect(NoteRow.trailingSlot(isHovered: false, peeks: false) == .age)
        #expect(NoteRow.trailingSlot(isHovered: true, peeks: false) == .chevron)
    }

    @Test func anExpandedRowKeepsTheChevronWhenTheCursorLeaves() {
        #expect(NoteRow.trailingSlot(isHovered: true, peeks: true) == .chevron)
        #expect(NoteRow.trailingSlot(isHovered: false, peeks: true) == .chevron)
    }
}
