import SwiftUI

struct PopoverView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            Text("Obsido")
                .font(.title2)
            Text("No file configured yet")
                .foregroundStyle(.secondary)
            Spacer()
            Divider()
            HStack {
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .padding(8)
        }
        .frame(width: 360, height: 480)
    }
}
