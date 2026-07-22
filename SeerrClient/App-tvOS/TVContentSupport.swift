// TVContentSupport.swift
// SeerrClientTV (Octopus Explorer)
//
// Shared tvOS-only presentation primitives for the Milestone 3 screens.

import SwiftUI

enum TVMetrics {
    static let horizontalInset: CGFloat = 80
    static let verticalInset: CGFloat = 60
    static let railSpacing: CGFloat = 40
    static let posterWidth: CGFloat = 220
    static let compactPosterWidth: CGFloat = 180
    static let cornerRadius: CGFloat = 8
}

struct TVScreenScaffold<Content: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color(red: 0.05, green: 0.067, blue: 0.11).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 36) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(title)
                            .font(.system(size: 76, weight: .bold))
                            .foregroundStyle(.white)
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 29, weight: .regular))
                                .foregroundStyle(.white.opacity(0.62))
                        }
                    }
                    content
                }
                .padding(.horizontal, TVMetrics.horizontalInset)
                .padding(.vertical, TVMetrics.verticalInset)
            }
        }
    }
}

struct TVLoadingStateView: View {
    let title: String

    var body: some View {
        TVScreenScaffold(title: title, subtitle: nil) {
            HStack(spacing: 24) {
                ProgressView()
                    .scaleEffect(1.8)
                Text("Loading")
                    .font(.system(size: 29, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .frame(maxWidth: .infinity, minHeight: 360, alignment: .center)
        }
    }
}

struct TVMessageStateView: View {
    let title: String
    let message: String
    let systemImage: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        TVScreenScaffold(title: title, subtitle: nil) {
            VStack(spacing: 24) {
                Image(systemName: systemImage)
                    .font(.system(size: 84, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                Text(message)
                    .font(.system(size: 29, weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: 900)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 420, alignment: .center)
        }
    }
}

struct TVFilterChip<Value: Hashable>: View {
    let title: String
    let value: Value
    @Binding var selection: Value

    var body: some View {
        Button {
            selection = value
        } label: {
            Text(title)
                .font(.system(size: 25, weight: .semibold))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .tint(selection == value ? .accentColor : .white.opacity(0.25))
    }
}

struct TVMediaPosterCard: View {
    let title: String
    let subtitle: String?
    let posterPath: String?
    let status: Int?
    var width: CGFloat = TVMetrics.posterWidth

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: TVMetrics.cornerRadius)
                    .fill(Color.white.opacity(0.12))
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)
                    .overlay {
                        if let posterPath, let url = TMDBImageURL.poster(path: posterPath, size: .w342) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                case .failure:
                                    posterFallback
                                case .empty:
                                    ProgressView()
                                @unknown default:
                                    posterFallback
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
                        } else {
                            posterFallback
                        }
                    }
                    .clipped()

                if let status, let code = MediaStatusCode(rawValue: status), code.showsBadge {
                    Text(code.label)
                        .font(.system(size: 18, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusColor(code), in: Capsule())
                        .foregroundStyle(.white)
                        .padding(10)
                }
            }

            // Reserve two lines so 1-line and 2-line titles keep a consistent card
            // height and the year below never gets pushed out / clipped when the
            // card scales up on focus.
            Text(title)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(2, reservesSpace: true)
                .multilineTextAlignment(.leading)
                .frame(width: width, alignment: .leading)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 21, weight: .regular))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
                    .frame(width: width, alignment: .leading)
            }
        }
        .frame(width: width, alignment: .topLeading)
    }

    private var posterFallback: some View {
        Image(systemName: "film")
            .font(.system(size: 58, weight: .semibold))
            .foregroundStyle(.white.opacity(0.35))
    }

    private func statusColor(_ code: MediaStatusCode) -> Color {
        switch code {
        case .available:
            return .green
        case .pending, .partiallyAvailable:
            return .orange
        case .processing:
            return .purple
        case .unknown, .deleted:
            return .gray
        }
    }
}

struct TVInfoPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(22)
        .frame(minWidth: 220, alignment: .leading)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: TVMetrics.cornerRadius))
    }
}
