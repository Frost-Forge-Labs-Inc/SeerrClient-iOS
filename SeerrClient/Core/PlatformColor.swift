// PlatformColor.swift
// SeerrClient
//
// Cross-platform Color shim. Maps semantic UIKit system colors to AppKit
// equivalents so shared and macOS views can use one API.
// M2b: macOS target membership only; iOS rollout is M3.

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
}
