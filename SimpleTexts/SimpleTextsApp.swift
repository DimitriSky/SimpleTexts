import AppKit
import SwiftUI

@main
struct SimpleTextsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Simple Texts", id: "main") {
            ContentView(store: appDelegate.store)
        }
        .defaultSize(width: 900, height: 600)
        .commands { NotesCommands(store: appDelegate.store) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = NotesStore()

    /// Closing the window keeps the notes; the Dock icon brings it back.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard store.hasContent else { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "Выйти из Simple Texts?"
        alert.informativeText = "Заметки хранятся только в памяти и пропадут после выхода."
        alert.addButton(withTitle: "Выйти")
        alert.addButton(withTitle: "Отмена")
        return alert.runModal() == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}

struct NotesCommands: Commands {
    let store: NotesStore

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Новая заметка") { store.addNote() }
                .keyboardShortcut("n")
            Button("Новый заголовок") { store.addHeader() }
                .keyboardShortcut("n", modifiers: [.command, .shift])
        }
        CommandMenu("Заметка") {
            Button(store.selectedIsPinned ? "Открепить" : "Закрепить") {
                if let id = store.selectedNoteID { store.togglePin(id) }
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(store.selectedNoteID == nil)

            Divider()

            Button("Предыдущая заметка") { store.selectAdjacent(-1) }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
            Button("Следующая заметка") { store.selectAdjacent(1) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])

            Divider()

            Button("Удалить заметку…") {
                if let id = store.selectedNoteID { store.requestDelete(id) }
            }
            .keyboardShortcut(.delete, modifiers: [.command, .option])
            .disabled(store.selectedNoteID == nil)
        }
    }
}
