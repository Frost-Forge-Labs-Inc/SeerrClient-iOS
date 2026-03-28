// ShimmerView.swift
// SeerrClient
//
// A simple shimmer animation overlay for skeleton loading states.
// Shared across features — used by MediaCardView, RequestListView, etc.

import SwiftUI

// MARK: - ShimmerView

/// A simple shimmer animation overlay for skeleton loading states.
struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: phase - 0.3),
                .init(color: .white.opacity(0.3), location: phase),
                .init(color: .clear, location: phase + 0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                phase = 2
            }
        }
    }
}
