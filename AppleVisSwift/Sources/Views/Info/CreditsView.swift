import SwiftUI

struct CreditsView: View {
    private let contributors = [
        Contributor(name: "AppleVis Community", role: "Content, Reviews, and Forum Discussions"),
        Contributor(name: "AppleVis Editorial Team", role: "Guides, Tutorials, and News Articles"),
        Contributor(name: "AppleVis Podcast Team", role: "Podcast Production and Hosting"),
    ]

    var body: some View {
        Form {
            Section {
                Text("AppleVis is built by and for the blindness and low-vision community. This app would not exist without the countless contributions from our members.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Contributors") {
                ForEach(contributors) { contributor in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(contributor.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(contributor.role)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                }
            }

            Section("Built With") {
                BuiltWithRow(tech: "SwiftUI", description: "Apple's declarative UI framework for native iOS development.")
                BuiltWithRow(tech: "AVFoundation", description: "Podcast playback, chapter support, and Now Playing integration.")
                BuiltWithRow(tech: "CloudKit / iCloud", description: "Sync across devices, protecting your data end-to-end.")
                BuiltWithRow(tech: "URLSession", description: "Networking and API communication with applevis.com.")
            }

            Section("Special Thanks") {
                Text("To every member of the AppleVis community who shares their knowledge to help others navigate the Apple ecosystem. Your dedication makes a real difference.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct Contributor: Identifiable {
    let id = UUID()
    let name: String
    let role: String
}

private struct BuiltWithRow: View {
    let tech: String
    let description: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(tech)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
