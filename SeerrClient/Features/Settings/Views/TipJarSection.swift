import SwiftUI

struct TipJarSection: View {
    @State private var isPresented = false

    var body: some View {
        Section {
            Button { isPresented = true } label: {
                Label("Tip the developer", systemImage: "heart")
            }
            .accessibilityIdentifier("tipJar.entry")
            .sheet(isPresented: $isPresented) { TipJarSheet() }
        } header: {
            Text("Support")
        }
    }
}
