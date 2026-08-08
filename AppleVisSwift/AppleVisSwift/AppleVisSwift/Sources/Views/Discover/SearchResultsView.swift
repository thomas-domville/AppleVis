import SwiftUI

struct SearchResultsView: View {
    @EnvironmentObject private var preferences: PreferencesStore
    let results: SearchResults?
    let isSearching: Bool
    let onRetry: () -> Void
    let onClearSearch: () -> Void

    var body: some View {
        Group {
            if isSearching {
                LoadingView()
            } else if let results {
                resultsList(results)
            } else {
                EmptyStateView(title: "No Results", message: "Try a different search term.", systemImage: "magnifyingglass")
            }
        }
    }

    @ViewBuilder
    private func resultsList(_ results: SearchResults) -> some View {
        let isEmpty = results.forums.isEmpty && results.apps.isEmpty && results.guides.isEmpty
            && results.blogs.isEmpty && results.podcasts.isEmpty && results.bugs.isEmpty
        if isEmpty && !results.failedCategories.isEmpty {
            // Distinct from a genuine zero-match search — every per-category
            // fetch previously swallowed its own errors silently, so a
            // network failure rendered the exact same "No Results" empty
            // state as an actual search with nothing matching, giving no
            // indication anything was wrong or worth retrying.
            ErrorView(message: "Some results may be missing. AppleVis search is using the available fallback sources.") {
                onRetry()
            }
        } else if isEmpty {
            EmptyStateView(
                title: "No Results",
                message: "Nothing matched your search. Check the spelling, use fewer words, or search for a broader topic.",
                systemImage: "magnifyingglass",
                primaryActionLabel: "Clear Search",
                primaryAction: onClearSearch
            )
        } else {
            List {
                if !results.failedCategories.isEmpty {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                                .accessibilityHidden(true)
                            Text("Some results may be missing: \(results.failedCategories.joined(separator: ", ")).")
                                .font(.footnote)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 8)
                            Button("Retry", action: onRetry)
                                .font(.footnote).fontWeight(.semibold)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Some results may be missing: \(results.failedCategories.joined(separator: ", ")).")
                        .accessibilityAction(named: Text("Retry"), onRetry)
                    }
                    .listRowSeparator(.hidden)
                }
                if !results.forums.isEmpty {
                    Section("Forums (\(results.forums.count))") {
                        ForEach(results.forums) { topic in
                            ForumTopicRow(topic: topic)
                        }
                    }
                }
                if !results.apps.isEmpty {
                    Section("Apps (\(results.apps.count))") {
                        ForEach(results.apps) { app in
                            AppListingRow(app: app)
                        }
                    }
                }
                if !results.guides.isEmpty {
                    Section("Guides (\(results.guides.count))") {
                        ForEach(results.guides) { guide in
                            ResourceRow(resource: guide)
                        }
                    }
                }
                if !results.blogs.isEmpty {
                    Section("Blogs (\(results.blogs.count))") {
                        ForEach(results.blogs) { post in
                            BlogPostRow(post: post)
                        }
                    }
                }
                if !results.podcasts.isEmpty {
                    Section("Podcasts (\(results.podcasts.count))") {
                        ForEach(results.podcasts) { episode in
                            PodcastEpisodeRow(episode: episode)
                        }
                    }
                }
                if !results.bugs.isEmpty {
                    Section("Bug Reports (\(results.bugs.count))") {
                        ForEach(results.bugs) { bug in
                            NavigationLink(value: bug) {
                                BugReportRow(bug: bug)
                            }
                        }
                    }
                }
            }
            .themedList(preferences.colors)
        }
    }
}
