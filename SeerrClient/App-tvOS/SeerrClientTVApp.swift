// SeerrClientTVApp.swift
// SeerrClientTV (Octopus Explorer — tvOS)
//
// Milestone 1 scaffold ONLY. This is a deliberately trivial @main entry that
// shows a placeholder view to prove the tvOS target compiles, links, and
// launches on the tvOS simulator. It does NOT wire up the shared AppState,
// ServerStore, or ContentView — that is Milestone 2 (nav shell).

import SwiftUI

@main
struct SeerrClientTVApp: App {
    var body: some Scene {
        WindowGroup {
            TVScaffoldPlaceholderView()
        }
    }
}

/// Placeholder root view for the empty tvOS scaffold (Milestone 1).
private struct TVScaffoldPlaceholderView: View {
    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.067, blue: 0.11)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Octopus Explorer — tvOS")
                    .font(.system(size: 76, weight: .bold))
                    .foregroundStyle(.white)
                Text("Milestone 1 scaffold")
                    .font(.system(size: 29, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

#Preview {
    TVScaffoldPlaceholderView()
}
