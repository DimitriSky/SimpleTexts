import SwiftUI

struct ContentView: View {
    @Bindable var store: NotesStore

    var body: some View {
        NavigationSplitView {
            Sidebar(store: store)
                .navigationSplitViewColumnWidth(min: 180, ideal: 240, max: 400)
        } detail: {
            EditorPane(store: store)
        }
        .alert(
            "Удалить заметку?",
            isPresented: Binding(
                get: { store.pendingDeletionID != nil },
                set: { if !$0 { store.pendingDeletionID = nil } }
            ),
            presenting: store.pendingDeletionID
        ) { id in
            Button("Удалить", role: .destructive) { store.deleteNote(id) }
            Button("Отмена", role: .cancel) {}
        } message: { _ in
            Text("Восстановить её будет нельзя.")
        }
    }
}

// MARK: - Sidebar

private struct Sidebar: View {
    @Bindable var store: NotesStore

    /// Headers can't be selected: a click on one only moves the insertion point.
    private var selection: Binding<UUID?> {
        Binding(
            get: { store.selectedNoteID },
            set: { id in
                guard let id else { return }
                if store.isHeader(id) {
                    store.activateHeader(id)
                } else {
                    store.select(id)
                }
            }
        )
    }

    var body: some View {
        List(selection: selection) {
            if !store.pinned.isEmpty {
                Section("Закреплённые") {
                    ForEach(store.pinned) { note in
                        NoteRow(note: note, store: store)
                    }
                    .onMove(perform: store.movePinned)
                }
            }
            Section {
                ForEach(store.items) { item in
                    switch item {
                    case .note(let note):
                        NoteRow(note: note, store: store)
                    case .header(let header):
                        HeaderRow(header: header, store: store)
                    }
                }
                .onMove(perform: store.moveItems)
            } header: {
                if !store.pinned.isEmpty { Text("Заметки") }
            }
        }
        .listStyle(.sidebar)
        .onDeleteCommand {
            if let id = store.selectedNoteID { store.requestDelete(id) }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { store.addHeader() } label: {
                    Label("Новый заголовок", systemImage: "textformat")
                }
                .help("Новый заголовок (⇧⌘N)")
                Button { store.addNote() } label: {
                    Label("Новая заметка", systemImage: "square.and.pencil")
                }
                .help("Новая заметка (⌘N)")
            }
        }
    }
}

private struct NoteRow: View {
    let note: Note
    let store: NotesStore

    var body: some View {
        let title = note.title
        Text(title.isEmpty ? "Новая заметка" : title)
            .lineLimit(1)
            .foregroundStyle(title.isEmpty ? .secondary : .primary)
            .contextMenu {
                Button(store.isPinned(note.id) ? "Открепить" : "Закрепить") { store.togglePin(note.id) }
                Divider()
                Button("Удалить…", role: .destructive) { store.requestDelete(note.id) }
            }
    }
}

private struct HeaderRow: View {
    let header: Header
    @Bindable var store: NotesStore
    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    private var isEditing: Bool { store.editingHeaderID == header.id }

    var body: some View {
        HStack(spacing: 6) {
            if isEditing {
                TextField("Заголовок", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                    .onAppear {
                        draft = header.title
                        DispatchQueue.main.async { fieldFocused = true }
                    }
                    .onSubmit(commit)
                    .onExitCommand(perform: commit)
                    .onChange(of: fieldFocused) { _, focused in
                        if !focused { commit() }
                    }
            } else {
                Text(header.title.isEmpty ? "Без названия" : header.title)
                    .lineLimit(1)
                    .fixedSize()
                Rectangle()
                    .fill(.separator)
                    .frame(height: 1)
            }
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { store.editingHeaderID = header.id }
        .contextMenu {
            Button("Переименовать") { store.editingHeaderID = header.id }
            Button("Новая заметка под заголовком") {
                store.activateHeader(header.id)
                store.addNote()
            }
            Divider()
            Button("Удалить заголовок", role: .destructive) { store.deleteHeader(header.id) }
        }
    }

    private func commit() {
        guard isEditing else { return }
        store.renameHeader(header.id, to: draft)
        store.editingHeaderID = nil
    }
}

// MARK: - Editor

private struct EditorPane: View {
    @Bindable var store: NotesStore
    @FocusState private var editorFocused: Bool

    var body: some View {
        Group {
            if let note = store.selectedNote {
                TextEditor(text: Binding(
                    get: { store.note(withID: note.id)?.text ?? "" },
                    set: { store.setText($0, for: note.id) }
                ))
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 10)
                .padding(.top, 6)
                .focused($editorFocused)
                .id(note.id)
                .background(Color(nsColor: .textBackgroundColor))
                .navigationTitle(note.title.isEmpty ? "Simple Texts" : note.title)
                .toolbar {
                    ToolbarItem {
                        Button { store.togglePin(note.id) } label: {
                            Label(
                                store.isPinned(note.id) ? "Открепить" : "Закрепить",
                                systemImage: store.isPinned(note.id) ? "pin.slash" : "pin"
                            )
                        }
                        .help(store.isPinned(note.id) ? "Открепить (⇧⌘P)" : "Закрепить (⇧⌘P)")
                    }
                }
            } else {
                ContentUnavailableView(
                    "Нет заметки",
                    systemImage: "note.text",
                    description: Text("⌘N — новая заметка")
                )
                .navigationTitle("Simple Texts")
            }
        }
        .onAppear(perform: focusEditor)
        .onChange(of: store.editorFocusRequest) { focusEditor() }
    }

    private func focusEditor() {
        DispatchQueue.main.async { editorFocused = true }
    }
}
