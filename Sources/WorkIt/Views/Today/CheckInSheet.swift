import SwiftUI

struct CheckInSheet: View {
    let occurrence: ExerciseOccurrence
    var onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: occurrence.activitySymbolName)
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)

                Text(occurrence.activityName)
                    .font(.title2.bold())

                if let targetDescription = occurrence.activityTargetDescription {
                    Text(targetDescription)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text("Mark it complete once you're done.")
                    .foregroundStyle(.secondary)

                Button {
                    onComplete()
                    dismiss()
                } label: {
                    Text("Mark Complete").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
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
