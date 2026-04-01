// AboutSection.swift
// SeerrClient
//
// App metadata and support links for the profile screen.

import SwiftUI

// MARK: - AboutSection

struct AboutSection: View {
    private let bugReportURL = URL(string: "https://github.com/seerr-team/seerr/issues/new/choose")

    var body: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text(versionString)
                    .foregroundStyle(.secondary)
            }

            if let bugReportURL {
                Link(destination: bugReportURL) {
                    HStack {
                        Text("Report a Bug")
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var versionString: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(shortVersion) (\(build))"
    }
}
