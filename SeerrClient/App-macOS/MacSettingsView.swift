// MacSettingsView.swift
// SeerrClientMac
//
// Preferences window content (Settings{} scene, ⌘,).
// Appearance (theme) + About. Theme key matches ProfileViewModel: "seerr.appTheme".

import SwiftUI

// MARK: - MacSettingsView

/// macOS Preferences window: Appearance (theme) and About (version + links).
struct MacSettingsView: View {

    /// Same UserDefaults key ProfileViewModel uses (`seerr.appTheme` Int rawValue).
    /// Default 0 = AppTheme.system.
    @AppStorage("seerr.appTheme") private var themeRaw: Int = AppTheme.system.rawValue

    private var selectedThemeBinding: Binding<AppTheme> {
        Binding(
            get: { AppTheme(rawValue: themeRaw) ?? .system },
            set: { themeRaw = $0.rawValue }
        )
    }

    var body: some View {
        TabView {
            appearanceTab
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            aboutTab
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 480, height: 360)
    }

    // MARK: - Appearance

    private var appearanceTab: some View {
        Form {
            AppearanceSection(selectedTheme: selectedThemeBinding)
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - About

    private var aboutTab: some View {
        Form {
            AboutSection()
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Preview

#Preview {
    MacSettingsView()
}
