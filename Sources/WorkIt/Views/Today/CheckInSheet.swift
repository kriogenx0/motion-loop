import SwiftUI

struct CheckInSheet: View {
    let occurrence: ExerciseOccurrence
    var onComplete: () -> Void
    var onMissed: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: occurrence.activity?.symbolName ?? "figure.run")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)

                Text(occurrence.activity?.name ?? "Activity")
                    .font(.title2.bold())

                if let targetDescription = occurrence.activity?.targetDescription {
                    Text(targetDescription)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text("Did you complete it?")
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Button {
                        onMissed()
                        dismiss()
                    } label: {
                        Text("No").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)

                    Button {
                        onComplete()
                        dismiss()
                    } label: {
                        Text("Yes").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)
                .padding(.top, 8)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
