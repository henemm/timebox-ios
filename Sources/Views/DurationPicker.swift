import SwiftUI

struct DurationPicker: View {
    let currentDuration: Int
    let onSelect: (Int?) -> Void

    private let options = [5, 15, 30, 60]

    var body: some View {
        VStack(spacing: 16) {
            Text("Dauer waehlen")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach(options, id: \.self) { minutes in
                    Button("\(minutes)m") {
                        onSelect(minutes)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(minutes == currentDuration ? .blue : .gray)
                }
            }

            Button("Zuruecksetzen") {
                onSelect(nil)
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .presentationDetents([.height(180)])
    }
}
