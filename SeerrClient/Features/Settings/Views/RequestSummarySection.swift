// RequestSummarySection.swift
// SeerrClient
//
// Admin-only request statistics section for the profile screen.

import SwiftUI

// MARK: - RequestSummarySection

struct RequestSummarySection: View {
    let requestCounts: RequestCounts?
    let isAdmin: Bool

    var body: some View {
        if isAdmin {
            Section("Request Summary") {
                HStack(spacing: 12) {
                    statCard(value: requestCounts?.total ?? 0, label: "Total")
                    statCard(value: requestCounts?.pending ?? 0, label: "Pending")
                    statCard(value: requestCounts?.available ?? 0, label: "Available")
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func statCard(value: Int, label: String) -> some View {
        VStack(spacing: 6) {
            Text("\(value)")
                .font(.title2.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
