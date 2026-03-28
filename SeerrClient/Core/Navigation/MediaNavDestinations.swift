// MediaNavDestinations.swift
// SeerrClient
//
// Hashable navigation destination values used with NavigationStack's
// value-based NavigationLink and .navigationDestination(for:) modifiers.

import Foundation
import SwiftUI

// MARK: - Movie Navigation

/// Navigation destination for a movie detail screen.
public struct MovieNavDestination: Hashable {
    public let id: Int
    public let title: String
}

// MARK: - TV Show Navigation

/// Navigation destination for a TV show detail screen.
public struct TvNavDestination: Hashable {
    public let id: Int
    public let title: String
}

// MARK: - Navigation Button Style

/// Button style for NavigationLink-wrapped media cards.
/// Provides the same subtle scale animation as MediaCardButtonStyle.
public struct MediaCardNavigationStyle: ButtonStyle {
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}
