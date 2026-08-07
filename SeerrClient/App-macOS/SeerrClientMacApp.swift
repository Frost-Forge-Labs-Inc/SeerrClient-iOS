import SwiftUI

@main
struct SeerrClientMacApp: App {
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 16) {
                Image(systemName: "play.tv.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.tint)
                Text("Octopus Explorer for Mac")
                    .font(.largeTitle.weight(.semibold))
                Text("macOS target scaffold — M1")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 900, idealWidth: 1200, maxWidth: .infinity,
                   minHeight: 600, idealHeight: 800, maxHeight: .infinity)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1200, height: 800)
    }
}
