import Foundation
import Observation
import SwiftUI // Array.move(fromOffsets:toOffset:)

struct Note: Identifiable, Equatable {
    let id: UUID
    var text: String

    init(id: UUID = UUID(), text: String = "") {
        self.id = id
        self.text = text
    }

    /// First non-empty line, used as the tab title.
    var title: String {
        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { return String(trimmed.prefix(80)) }
        }
        return ""
    }

    var isBlank: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}

struct Header: Identifiable, Equatable {
    let id: UUID
    var title: String

    init(id: UUID = UUID(), title: String = "") {
        self.id = id
        self.title = title
    }
}

enum SidebarItem: Identifiable, Equatable {
    case note(Note)
    case header(Header)

    var id: UUID {
        switch self {
        case .note(let note): note.id
        case .header(let header): header.id
        }
    }
}

/// All notes live only in memory; nothing is written to disk.
@MainActor
@Observable
final class NotesStore {
    /// Where a pinned note goes back to when it is unpinned.
    private enum Origin: Equatable {
        case top
        case after(UUID)
    }

    /// Unpinned notes and headers, in sidebar order.
    private(set) var items: [SidebarItem] = []
    /// Pinned notes, shown above everything else.
    private(set) var pinned: [Note] = []
    private(set) var selectedNoteID: UUID?
    /// Header whose title is being edited inline.
    var editingHeaderID: UUID?
    /// Note waiting for delete confirmation.
    var pendingDeletionID: UUID?
    /// Bumped when the editor should take keyboard focus.
    private(set) var editorFocusRequest = 0

    /// New notes and headers are inserted right after this item.
    private var anchorID: UUID?
    private var pinOrigins: [UUID: Origin] = [:]

    init(startWithEmptyNote: Bool = true) {
        if startWithEmptyNote {
            let note = Note()
            items = [.note(note)]
            select(note.id)
        }
    }

    // MARK: Reading

    var selectedNote: Note? { selectedNoteID.flatMap(note(withID:)) }

    var selectedIsPinned: Bool { selectedNoteID.map(isPinned) ?? false }

    var hasContent: Bool {
        pinned.contains { !$0.isBlank } || items.contains {
            if case .note(let note) = $0 { return !note.isBlank }
            return false
        }
    }

    /// Notes in the order they appear in the sidebar: pinned first.
    var orderedNoteIDs: [UUID] {
        pinned.map(\.id) + items.compactMap {
            if case .note(let note) = $0 { return note.id }
            return nil
        }
    }

    func note(withID id: UUID) -> Note? {
        if let note = pinned.first(where: { $0.id == id }) { return note }
        for case .note(let note) in items where note.id == id { return note }
        return nil
    }

    func isPinned(_ id: UUID) -> Bool { pinned.contains { $0.id == id } }

    func isHeader(_ id: UUID) -> Bool {
        items.contains { if case .header(let header) = $0 { header.id == id } else { false } }
    }

    // MARK: Selection

    func select(_ id: UUID?) {
        guard let id else {
            selectedNoteID = nil
            return
        }
        guard note(withID: id) != nil else { return }
        selectedNoteID = id
        anchorID = id
    }

    /// Clicking a header makes it the insertion point without changing the open note.
    func activateHeader(_ id: UUID) {
        guard isHeader(id) else { return }
        anchorID = id
    }

    func selectAdjacent(_ offset: Int) {
        let ids = orderedNoteIDs
        guard !ids.isEmpty else { return }
        guard let current = selectedNoteID, let index = ids.firstIndex(of: current) else {
            select(offset >= 0 ? ids.first : ids.last)
            return
        }
        select(ids[min(max(index + offset, 0), ids.count - 1)])
    }

    // MARK: Editing

    func setText(_ text: String, for id: UUID) {
        if let index = pinned.firstIndex(where: { $0.id == id }) {
            pinned[index].text = text
        } else if let index = items.firstIndex(where: { $0.id == id }), case .note(var note) = items[index] {
            note.text = text
            items[index] = .note(note)
        }
    }

    @discardableResult
    func addNote(text: String = "") -> UUID {
        let note = Note(text: text)
        items.insert(.note(note), at: insertionIndex())
        select(note.id)
        editorFocusRequest += 1
        return note.id
    }

    @discardableResult
    func addHeader(title: String = "", editing: Bool = true) -> UUID {
        let header = Header(title: title)
        items.insert(.header(header), at: insertionIndex())
        anchorID = header.id
        if editing { editingHeaderID = header.id }
        return header.id
    }

    func renameHeader(_ id: UUID, to title: String) {
        guard let index = items.firstIndex(where: { $0.id == id }), case .header(var header) = items[index] else { return }
        header.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        items[index] = .header(header)
    }

    func deleteHeader(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }), case .header = items[index] else { return }
        removeItem(at: index)
        if editingHeaderID == id { editingHeaderID = nil }
    }

    /// Blank notes go away at once; notes with text ask first.
    func requestDelete(_ id: UUID) {
        guard let note = note(withID: id) else { return }
        if note.isBlank {
            deleteNote(id)
        } else {
            pendingDeletionID = id
        }
    }

    func deleteNote(_ id: UUID) {
        let ids = orderedNoteIDs
        guard let position = ids.firstIndex(of: id) else { return }
        let neighbour = position + 1 < ids.count ? ids[position + 1] : (position > 0 ? ids[position - 1] : nil)

        if let index = pinned.firstIndex(where: { $0.id == id }) {
            pinned.remove(at: index)
            pinOrigins[id] = nil
        } else if let index = items.firstIndex(where: { $0.id == id }) {
            removeItem(at: index)
        }
        if pendingDeletionID == id { pendingDeletionID = nil }
        if selectedNoteID == id { select(neighbour) }
        if anchorID == id { anchorID = selectedNoteID }
    }

    // MARK: Pinning

    func togglePin(_ id: UUID) {
        isPinned(id) ? unpin(id) : pin(id)
    }

    func pin(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }), case .note(let note) = items[index] else { return }
        let origin: Origin = index == 0 ? .top : .after(items[index - 1].id)
        removeItem(at: index)
        pinOrigins[id] = origin
        pinned.append(note)
    }

    func unpin(_ id: UUID) {
        guard let index = pinned.firstIndex(where: { $0.id == id }) else { return }
        let note = pinned.remove(at: index)
        let target: Int
        switch pinOrigins.removeValue(forKey: id) ?? .top {
        case .top:
            target = 0
        case .after(let previous):
            target = items.firstIndex(where: { $0.id == previous }).map { $0 + 1 } ?? items.count
        }
        items.insert(.note(note), at: target)
    }

    // MARK: Reordering

    func moveItems(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
    }

    func movePinned(from source: IndexSet, to destination: Int) {
        pinned.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: Private

    private func insertionIndex() -> Int {
        if let anchorID, let index = items.firstIndex(where: { $0.id == anchorID }) {
            return index + 1
        }
        return items.count
    }

    /// Removes an item and re-points pinned notes that would have returned after it.
    private func removeItem(at index: Int) {
        let removedID = items[index].id
        let replacement: Origin = index == 0 ? .top : .after(items[index - 1].id)
        items.remove(at: index)
        for (noteID, origin) in pinOrigins where origin == .after(removedID) {
            pinOrigins[noteID] = replacement
        }
    }
}
