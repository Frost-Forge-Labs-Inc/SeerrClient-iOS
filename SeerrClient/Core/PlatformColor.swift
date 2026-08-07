// PlatformColor.swift
// SeerrClient
//
// Cross-platform Color shim. Maps semantic UIKit system colors to AppKit
// equivalents so shared and macOS views can use one API.
// Shared by both iOS and macOS targets (behavior-preserving on iOS).

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Platform Color Shim

extension Color {

    /// Secondary / grouped control background (form fields, chips).
    static var platformSecondaryBackground: Color {
        #if os(macOS)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color(uiColor: .secondarySystemBackground)
        #endif
    }

    /// Grouped content background (list rows, cards).
    static var platformGroupedBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemGroupedBackground)
        #endif
    }

    /// Primary system background (loading overlays, full-bleed fills).
    static var platformSystemBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }

    /// Secondary grouped background (inset-grouped list rows).
    static var platformSecondaryGroupedBackground: Color {
        #if os(macOS)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }

    /// Skeleton / placeholder fill (systemGray5 on iOS).
    static var platformFill: Color {
        #if os(macOS)
        Color(nsColor: .quaternaryLabelColor)
        #else
        Color(.systemGray5)
        #endif
    }

    /// Lighter skeleton / secondary placeholder fill (systemGray6 on iOS).
    static var platformSecondaryFill: Color {
        #if os(macOS)
        Color(nsColor: .quaternaryLabelColor).opacity(0.5)
        #else
        Color(.systemGray6)
        #endif
    }

    /// Stronger placeholder / gradient end fill (systemGray4 on iOS).
    static var platformTertiaryFill: Color {
        #if os(macOS)
        Color(nsColor: .tertiaryLabelColor)
        #else
        Color(.systemGray4)
        #endif
    }
}
