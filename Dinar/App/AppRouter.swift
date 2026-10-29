import Observation
import SwiftUI
import SwiftData

enum AppTab: Hashable {
    case home
    case transactions
    case reports
    case budgets
}

/// What the transaction editor sheet is showing.
enum EditorRequest: Identifiable {
    case new(EntryKind)
    case edit(LedgerEntry)

    var id: String {
        switch self {
        case .new(let kind): "new-\(kind.rawValue)"
        case .edit(let entry): "edit-\(entry.persistentModelID.hashValue)"
        }
    }
}

/// App-wide navigation state: selected tab and modal sheets.
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    var editor: EditorRequest?
    var isShowingSettings = false

    func newEntry(_ kind: EntryKind = .expense) { editor = .new(kind) }
    func edit(_ entry: LedgerEntry) { editor = .edit(entry) }
}
