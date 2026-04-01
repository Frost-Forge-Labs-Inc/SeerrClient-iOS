// AppearanceSection.swift
// SeerrClient
//
// App theme preference controls for the profile screen.

import SwiftUI

// MARK: - AppearanceSection

struct AppearanceSection: View {
    @Binding var selectedTheme: AppTheme

    var body: some View {
        Section("Appearance") {
            Picker("Theme", selection: $selectedTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.displayName)
                        .tag(theme)
                }
            }
            .pickerStyle(.segmented)
        }
    }
}
