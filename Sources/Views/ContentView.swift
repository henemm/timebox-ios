import AppIntents
import SwiftUI

struct ContentView: View {
    @State private var showGetNextUpTip = true

    var body: some View {
        VStack(spacing: 0) {
            // ITB-G4: Siri Tip for "What's next?" shortcut discovery
            SiriTipView(intent: GetNextUpIntent(), isVisible: $showGetNextUpTip)
                .padding(.horizontal)

            MainTabView()
        }
    }
}
