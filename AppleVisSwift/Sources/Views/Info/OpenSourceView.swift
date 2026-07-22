import SwiftUI

struct OpenSourceView: View {
    private let licences: [OpenSourceLicence] = [
        OpenSourceLicence(
            name: "Swift",
            url: "https://github.com/apple/swift",
            licence: "Apache License 2.0",
            copyright: "Copyright © 2014 Apple Inc. and the Swift project authors."
        ),
        OpenSourceLicence(
            name: "SwiftUI",
            url: "https://developer.apple.com/xcode/swiftui/",
            licence: "Apple Proprietary",
            copyright: "Copyright © Apple Inc. All rights reserved."
        ),
    ]

    var body: some View {
        Form {
            Section {
                Text("AppleVis is built using Apple's native frameworks and standard system libraries. The following open-source components are used in this app.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Licences") {
                ForEach(licences) { item in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(item.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(item.licence)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.12), in: Capsule())
                                .foregroundStyle(.accent)
                        }
                        Text(item.copyright)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let url = URL(string: item.url) {
                            Link("View on GitHub", destination: url)
                                .font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }

            Section {
                Text("AppleVis itself is not open source. All app code is copyright AppleVis and its contributors.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Open Source Licences")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct OpenSourceLicence: Identifiable {
    let id = UUID()
    let name: String
    let url: String
    let licence: String
    let copyright: String
}
