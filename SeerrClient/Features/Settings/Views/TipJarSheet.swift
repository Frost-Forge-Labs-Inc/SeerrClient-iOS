import SwiftUI

struct TipJarSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = TipJarViewModel.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Support Octopus Explorer development").font(.title2.bold())
                    Text(TipJarViewModel.disclosure)
                        .accessibilityIdentifier("tipJar.disclosure")
                    status
                    ForEach(viewModel.products) { product in
                        Button {
                            Task { await viewModel.purchase(product) }
                        } label: {
                            HStack {
                                Text(product.displayName)
                                Spacer()
                                Text(product.displayPrice)
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isBusy)
                        .accessibilityIdentifier("tipJar.product.\(product.id)")
                    }
                    Text("Tips are optional, repeatable purchases. Consumed tips cannot be restored.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("tipJar.done")
                }
                .padding(24)
            }
            .navigationTitle("Tip the developer")
            .accessibilityIdentifier("tipJar.sheet")
        }
        #if os(macOS)
        .frame(minWidth: 440, minHeight: 440)
        #endif
        .task { if viewModel.products.isEmpty { await viewModel.load() } }
    }

    @ViewBuilder private var status: some View {
        switch viewModel.state {
        case .idle, .ready: EmptyView()
        case .loading, .purchasing: ProgressView()
        case .pending:
            Text("Your tip is awaiting approval. Thank you for your patience.")
        case .thankYou:
            Label("Thank you for supporting Octopus Explorer!", systemImage: "heart.fill")
                .accessibilityIdentifier("tipJar.thankYou")
        case .error(let message):
            Text(message).foregroundStyle(.secondary)
            Button("Try Again") { Task { await viewModel.load() } }
                .disabled(viewModel.isBusy)
        }
    }
}
