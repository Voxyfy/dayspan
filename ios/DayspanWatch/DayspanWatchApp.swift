import SwiftUI

/// Dayspan'in saat uygulaması: günün panosu bilekte.
///
/// Veri telefondan gelir (`WatchBridge.swift`), saat yalnızca çizer ve
/// dokunuşu geri yollar. Hesap yok, veritabanı yok: iki cihazın ayrı
/// sayması uyumsuzlukla biterdi.
@main
struct DayspanWatchApp: App {
    @StateObject private var store = BoardStore()

    var body: some Scene {
        WindowGroup {
            BoardView()
                .environmentObject(store)
        }
    }
}
