import SwiftUI

/// Every symbol used by a bundled preset, deduped, plus a few extras -- kept
/// as a flat curated set rather than the whole SF Symbols catalog so the grid
/// stays a quick scroll, not a search problem of its own.
enum IconChoices {
    static let all: [String] = {
        var seen = Set<String>()
        var result: [String] = []
        for symbol in PresetActivities.all.map(\.symbolName) + extras where seen.insert(symbol).inserted {
            result.append(symbol)
        }
        return result
    }()

    private static let extras = [
        "dumbbell.fill",
        "figure.mixed.cardio",
        "figure.climbing",
        "sportscourt.fill",
        "heart.fill",
        PresetActivities.customSymbolName,
    ]
}

/// Lets the user override an activity's icon directly, independent of
/// whatever the typed name auto-resolves to -- picking any symbol from the
/// curated set in `IconChoices`.
struct IconPickerView: View {
    @Binding var selection: String
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 56), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(IconChoices.all, id: \.self) { symbol in
                        Button {
                            selection = symbol
                            dismiss()
                        } label: {
                            Image(systemName: symbol)
                                .font(.title2)
                                .frame(width: 52, height: 52)
                                .background(
                                    selection == symbol ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                                .foregroundStyle(selection == symbol ? Color.accentColor : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Icon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
