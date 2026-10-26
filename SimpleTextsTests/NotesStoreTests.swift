import XCTest
@testable import SimpleTexts

@MainActor
final class NotesStoreTests: XCTestCase {
    private func sidebarIDs(_ store: NotesStore) -> [UUID] { store.items.map(\.id) }

    func testStartsWithOneSelectedEmptyNote() {
        let store = NotesStore()
        XCTAssertEqual(store.items.count, 1)
        XCTAssertNotNil(store.selectedNote)
        XCTAssertFalse(store.hasContent)
    }

    func testTitleIsFirstNonEmptyLine() {
        XCTAssertEqual(Note(text: "\n  \n  Список покупок  \nмолоко").title, "Список покупок")
        XCTAssertEqual(Note(text: "   ").title, "")
    }

    func testNewNoteGoesAfterSelectedNote() {
        let store = NotesStore(startWithEmptyNote: false)
        let a = store.addNote()
        let b = store.addNote()
        store.select(a)
        let c = store.addNote()
        XCTAssertEqual(sidebarIDs(store), [a, c, b])
        XCTAssertEqual(store.selectedNoteID, c)
    }

    func testNotesAfterNewHeaderGoUnderIt() {
        let store = NotesStore(startWithEmptyNote: false)
        let a = store.addNote()
        let header = store.addHeader(title: "Работа")
        let b = store.addNote()
        XCTAssertEqual(sidebarIDs(store), [a, header, b])
    }

    func testHeaderCannotBeSelected() {
        let store = NotesStore(startWithEmptyNote: false)
        let a = store.addNote()
        let header = store.addHeader(title: "X")
        store.select(header)
        XCTAssertEqual(store.selectedNoteID, a)
    }

    func testPinAndUnpinRestoresPosition() {
        let store = NotesStore(startWithEmptyNote: false)
        let a = store.addNote()
        let header = store.addHeader(title: "H")
        let b = store.addNote()
        let c = store.addNote()

        store.pin(b)
        XCTAssertEqual(store.pinned.map(\.id), [b])
        XCTAssertEqual(sidebarIDs(store), [a, header, c])
        XCTAssertEqual(store.orderedNoteIDs, [b, a, c])

        store.unpin(b)
        XCTAssertTrue(store.pinned.isEmpty)
        XCTAssertEqual(sidebarIDs(store), [a, header, b, c])
    }

    func testUnpinAfterPredecessorDeleted() {
        let store = NotesStore(startWithEmptyNote: false)
        let a = store.addNote()
        let b = store.addNote()
        let c = store.addNote()
        store.pin(c)
        store.deleteNote(b)
        store.unpin(c)
        XCTAssertEqual(sidebarIDs(store), [a, c])

        store.pin(a)
        store.deleteNote(c)
        store.unpin(a)
        XCTAssertEqual(sidebarIDs(store), [a])
    }

    func testTextEditsWorkForPinnedAndUnpinned() {
        let store = NotesStore(startWithEmptyNote: false)
        let a = store.addNote()
        let b = store.addNote()
        store.pin(b)
        store.setText("один", for: a)
        store.setText("два", for: b)
        XCTAssertEqual(store.note(withID: a)?.text, "один")
        XCTAssertEqual(store.note(withID: b)?.text, "два")
        XCTAssertTrue(store.hasContent)
    }

    func testDeleteSelectsNeighbour() {
        let store = NotesStore(startWithEmptyNote: false)
        let a = store.addNote()
        let b = store.addNote()
        store.deleteNote(b)
        XCTAssertEqual(store.selectedNoteID, a)
        store.deleteNote(a)
        XCTAssertNil(store.selectedNoteID)
    }

    func testBlankNoteDeletesWithoutConfirmation() {
        let store = NotesStore(startWithEmptyNote: false)
        let a = store.addNote()
        let b = store.addNote(text: "важное")
        store.requestDelete(a)
        XCTAssertNil(store.note(withID: a))
        store.requestDelete(b)
        XCTAssertNotNil(store.note(withID: b))
        XCTAssertEqual(store.pendingDeletionID, b)
    }

    func testSelectAdjacentWalksPinnedThenList() {
        let store = NotesStore(startWithEmptyNote: false)
        let a = store.addNote()
        let b = store.addNote()
        store.pin(b)
        store.select(b)
        store.selectAdjacent(1)
        XCTAssertEqual(store.selectedNoteID, a)
        store.selectAdjacent(1)
        XCTAssertEqual(store.selectedNoteID, a)
        store.selectAdjacent(-1)
        XCTAssertEqual(store.selectedNoteID, b)
    }

    func testDeleteHeaderKeepsNotes() {
        let store = NotesStore(startWithEmptyNote: false)
        let header = store.addHeader(title: "H")
        let a = store.addNote()
        store.deleteHeader(header)
        XCTAssertEqual(sidebarIDs(store), [a])
    }

    func testRenameHeaderTrims() {
        let store = NotesStore(startWithEmptyNote: false)
        let header = store.addHeader()
        store.renameHeader(header, to: "  Идеи  ")
        guard case .header(let value) = store.items.first else { return XCTFail() }
        XCTAssertEqual(value.title, "Идеи")
    }
}
