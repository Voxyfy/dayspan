import Foundation
import WatchConnectivity

/// Telefonun yazdığı pano. Alan adları lib/core/watch_bridge.dart ile aynı.
struct Board: Codable, Equatable {
    struct Task: Codable, Equatable, Identifiable {
        let id: Int
        let title: String
        let time: String?
        var done: Bool
    }
    struct Habit: Codable, Equatable, Identifiable {
        let id: Int
        let name: String
        let color: Int
        var done: Bool
        var count: Int
        let target: Int
        /// Dokunuşta gönderilecek yeni sayı; hesabı telefon yaptı.
        let next: Int
    }
    /// Telefonun dilindeki başlıklar; saat kendi çevirisini taşımaz.
    struct Strings: Codable, Equatable {
        var today = "Today"
        var left = "Done"
        var nothing = "Nothing planned."
        var openOnce = "Open Dayspan on your iPhone once."
    }
    var date: String
    var strings: Strings? = Strings()
    var tasks: [Task]
    var habits: [Habit]

    static let empty = Board(date: "", tasks: [], habits: [])

    var text: Strings { strings ?? Strings() }

    var pending: Int {
        tasks.filter { !$0.done }.count + habits.filter { !$0.done }.count
    }
}

/// WatchConnectivity oturumu ve panonun tek kopyası.
///
/// Son pano UserDefaults'ta da durur: saat uygulaması açılınca telefon
/// uyanmamış olabilir, boş ekran yerine son bilinen pano gösterilir.
final class BoardStore: NSObject, ObservableObject, WCSessionDelegate {
    @Published private(set) var board: Board = .empty
    @Published private(set) var phoneReachable = false

    private let defaults = UserDefaults.standard
    private let key = "board"

    override init() {
        super.init()
        if let raw = defaults.string(forKey: key) { apply(raw) }
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    private func apply(_ json: String) {
        guard let data = json.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(Board.self, from: data)
        else { return }
        DispatchQueue.main.async {
            self.board = parsed
            self.defaults.set(json, forKey: self.key)
        }
    }

    // MARK: Eylemler

    func toggle(_ habit: Board.Habit) {
        // İyimser güncelleme: telefonun cevabı gelene kadar dokunuş ekranda
        // görünsün. Gerçek hâl bir sonraki panoyla üstüne yazılır.
        if let i = board.habits.firstIndex(where: { $0.id == habit.id }) {
            board.habits[i].done = habit.next >= habit.target
            board.habits[i].count = habit.next
        }
        send(["type": "habit", "id": habit.id, "count": habit.next])
    }

    func toggle(_ task: Board.Task) {
        if let i = board.tasks.firstIndex(where: { $0.id == task.id }) {
            board.tasks[i].done.toggle()
        }
        send(["type": "task", "id": task.id, "done": !task.done])
    }

    private func send(_ payload: [String: Any]) {
        let session = WCSession.default
        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { _ in
                // Ulaşılamadı: kuyruğa. transferUserInfo telefon uyanınca teslim eder.
                session.transferUserInfo(payload)
            }
        } else {
            session.transferUserInfo(payload)
        }
    }

    // MARK: WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
        if let raw = session.receivedApplicationContext["board"] as? String { apply(raw) }
        DispatchQueue.main.async { self.phoneReachable = session.isReachable }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.phoneReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveApplicationContext context: [String: Any]) {
        if let raw = context["board"] as? String { apply(raw) }
    }
}
