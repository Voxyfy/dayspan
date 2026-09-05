import SwiftUI

// lib/core/theme/app_colors.dart içindeki TilePalette ile aynı sıra; her
// rengin kendi mürekkebi (açık zeminde siyah yazı).
struct TileColor {
    let fill: Color
    let ink: Color
}

let tilePalette: [TileColor] = [
    TileColor(fill: Color(red: 0.11, green: 0.11, blue: 0.13), ink: .white),
    TileColor(fill: Color(red: 0.83, green: 0.00, blue: 1.00), ink: .white),
    TileColor(fill: Color(red: 0.29, green: 0.24, blue: 1.00), ink: .white),
    TileColor(fill: Color(red: 0.95, green: 0.95, blue: 0.16), ink: Color(red: 0.04, green: 0.04, blue: 0.05)),
    TileColor(fill: Color(red: 1.00, green: 0.24, blue: 0.35), ink: .white),
    TileColor(fill: Color(red: 0.12, green: 0.53, blue: 1.00), ink: .white),
    TileColor(fill: Color(red: 0.71, green: 0.36, blue: 1.00), ink: Color(red: 0.04, green: 0.04, blue: 0.05)),
    TileColor(fill: Color(red: 0.20, green: 0.78, blue: 0.35), ink: Color(red: 0.04, green: 0.04, blue: 0.05)),
    TileColor(fill: Color(red: 1.00, green: 0.62, blue: 0.04), ink: Color(red: 0.04, green: 0.04, blue: 0.05)),
    TileColor(fill: Color(red: 0.00, green: 0.90, blue: 0.83), ink: Color(red: 0.04, green: 0.04, blue: 0.05)),
]

let graphite = TileColor(fill: Color(red: 0.11, green: 0.11, blue: 0.13), ink: .white)
let doneGreen = Color(red: 0.20, green: 0.78, blue: 0.35)

/// Günün panosu: önce işler (grafit), sonra alışkanlıklar (renkli). Telefonla
/// aynı dil: etiket yok, ayrım renkle; biten karo grafite döner.
struct BoardView: View {
    @EnvironmentObject var store: BoardStore

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                header
                if store.board.tasks.isEmpty && store.board.habits.isEmpty {
                    empty
                } else {
                    ForEach(store.board.tasks) { task in
                        TileRow(
                            title: task.title,
                            subtitle: task.time,
                            done: task.done,
                            color: graphite
                        ) { store.toggle(task) }
                    }
                    ForEach(store.board.habits) { habit in
                        TileRow(
                            title: habit.name,
                            subtitle: habit.target > 1 ? "\(habit.count)/\(habit.target)" : nil,
                            done: habit.done,
                            color: habit.done ? graphite : tilePalette[habit.color % tilePalette.count]
                        ) { store.toggle(habit) }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .background(Color(red: 0.04, green: 0.04, blue: 0.05))
    }

    var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(store.board.text.today).font(.headline)
            Spacer()
            Text(store.board.text.left)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 4)
    }

    var empty: some View {
        VStack(spacing: 6) {
            Text(store.board.date.isEmpty ? store.board.text.openOnce : store.board.text.nothing)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }
}

/// Bilek için karo: tek satır, solda ad, sağda onay dairesi. Telefondaki
/// ızgara burada liste; küçük ekranda iki sütun okunmuyor.
struct TileRow: View {
    let title: String
    let subtitle: String?
    let done: Bool
    let color: TileColor
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .foregroundStyle(done ? color.ink.opacity(0.5) : color.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundStyle(color.ink.opacity(0.65))
                    }
                }
                Spacer(minLength: 4)
                ZStack {
                    Circle()
                        .strokeBorder(done ? doneGreen : color.ink, lineWidth: 2)
                        .background(Circle().fill(done ? doneGreen : .clear))
                        .frame(width: 24, height: 24)
                    if done {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(red: 0.04, green: 0.04, blue: 0.05))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(color.fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
