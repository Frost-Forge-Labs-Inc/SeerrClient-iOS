// LaunchAnimationView.swift
// SeerrClient
//
// Full-screen animated launch/loading screen shown while session state is being
// resolved (cookie restore + /auth/me probe). Uses the BrandMascotTransparent
// image with the same dark-navy background as the AppIcon.

import SwiftUI

// MARK: - LaunchAnimationView

/// Animated splash screen displayed during auth session restoration.
///
/// Plays a continuous float + glow animation on the brand mascot and cycles
/// three loading dots below it. The background colour is sampled from the
/// app icon's dark-navy fill so the transition from the iOS launch screen
/// feels seamless.
struct LaunchAnimationView: View {

    // MARK: - Animation State

    @State private var isFloating   = false
    @State private var glowPulse    = false
    @State private var shimmerPhase = false
    @State private var appeared     = false
    @State private var dotIndex     = 0

    // MARK: - Constants

    /// Deep-navy background matching the system launch screen (#050D27).
    private let bgColor = Color(red: 0.01961, green: 0.05098, blue: 0.15294)

    /// Purple accent matching the mascot body.
    private let mascotPurple = Color(red: 0.51, green: 0.33, blue: 0.87)

    /// Cobalt-blue accent from the binocular lens.
    private let lensBlue = Color(red: 0.18, green: 0.45, blue: 0.95)

    // MARK: - Body

    var body: some View {
        ZStack {
            backgroundLayer
            contentStack
        }
        .onAppear {
            startAnimations()
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var backgroundLayer: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            // Soft radial glow centred behind the mascot — subtle depth.
            RadialGradient(
                colors: [
                    mascotPurple.opacity(glowPulse ? 0.14 : 0.06),
                    .clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: 280
            )
            .ignoresSafeArea()
            .scaleEffect(glowPulse ? 1.12 : 0.88)
        }
    }

    // MARK: - Content Stack

    @ViewBuilder
    private var contentStack: some View {
        VStack(spacing: 0) {
            Spacer()

            mascotSection

            Spacer().frame(height: 36)

            labelSection

            Spacer().frame(height: 28)

            dotsSection

            Spacer()
        }
    }

    // MARK: - Mascot

    @ViewBuilder
    private var mascotSection: some View {
        ZStack {
            // Outer glow ring — pulses in sync with float.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            mascotPurple.opacity(glowPulse ? 0.28 : 0.08),
                            .clear
                        ],
                        center: .center,
                        startRadius: 10,
                        endRadius: 120
                    )
                )
                .frame(width: 240, height: 240)
                .scaleEffect(glowPulse ? 1.10 : 0.90)

            // Inner lens shimmer ring — cobalt halo from binoculars.
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            lensBlue.opacity(shimmerPhase ? 0.55 : 0.10),
                            mascotPurple.opacity(shimmerPhase ? 0.20 : 0.05),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
                .frame(width: 168, height: 168)
                .rotationEffect(.degrees(shimmerPhase ? 60 : -60))

            // Mascot — floats vertically and breathes in scale.
            Image("BrandMascotTransparent")
                .resizable()
                .scaledToFit()
                .frame(width: 148, height: 148)
                .offset(y: isFloating ? -10 : 10)
                .scaleEffect(isFloating ? 1.04 : 0.96)
                // Drop shadow to lift the mascot off the background.
                .shadow(
                    color: mascotPurple.opacity(0.45),
                    radius: isFloating ? 24 : 14,
                    x: 0,
                    y: isFloating ? 10 : 4
                )
        }
    }

    // MARK: - Label

    @ViewBuilder
    private var labelSection: some View {
        VStack(spacing: 5) {
            Text("Octopus Explorer")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .tracking(0.5)

            Text("Loading your server…")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.38))
                .tracking(0.3)
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
    }

    // MARK: - Dots

    @ViewBuilder
    private var dotsSection: some View {
        HStack(spacing: 7) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(dotColor(for: i))
                    .frame(
                        width: dotIndex == i ? 18 : 7,
                        height: 7
                    )
                    .opacity(dotIndex == i ? 1.0 : 0.25)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: dotIndex)
        .opacity(appeared ? 1 : 0)
    }

    private func dotColor(for index: Int) -> Color {
        dotIndex == index ? mascotPurple : mascotPurple.opacity(0.5)
    }

    // MARK: - Animation Control

    private func startAnimations() {
        // Fade-in text + dots.
        withAnimation(.easeOut(duration: 0.55).delay(0.15)) {
            appeared = true
        }

        // Mascot float (matches glow so they're in sync).
        withAnimation(
            .easeInOut(duration: 2.2)
            .repeatForever(autoreverses: true)
        ) {
            isFloating = true
        }

        // Background + outer glow pulse (slightly slower for depth).
        withAnimation(
            .easeInOut(duration: 2.2)
            .repeatForever(autoreverses: true)
        ) {
            glowPulse = true
        }

        // Inner shimmer ring — slower rotation cycle.
        withAnimation(
            .easeInOut(duration: 3.6)
            .repeatForever(autoreverses: true)
        ) {
            shimmerPhase = true
        }

        // Loading dots — cycle every 420 ms via a background Task.
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 420_000_000)
                await MainActor.run {
                    dotIndex = (dotIndex + 1) % 3
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    LaunchAnimationView()
}
