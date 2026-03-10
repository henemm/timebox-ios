import AppIntents
import SwiftUI

struct ContentView: View {
    @AppStorage("siriTipGetNextUpVisible") private var showGetNextUpTip = true
    @Binding var selectedTab: AppTab

    var body: some View {
        VStack(spacing: 0) {
            // ITB-G4: Siri Tip for "What's next?" shortcut discovery
            SiriTipView(intent: GetNextUpIntent(), isVisible: $showGetNextUpTip)
                .padding(.horizontal)

            MainTabView(selectedTab: $selectedTab)
        }
    }
}
