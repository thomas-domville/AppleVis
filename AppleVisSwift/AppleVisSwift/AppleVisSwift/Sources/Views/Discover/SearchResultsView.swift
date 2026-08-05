import SwiftUI

struct SearchResultsView: View {
    let results: SearchResults?
    let isSearching: Bool

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
        if isEmpty {
            EmptyStateView(title: "No Results", message: "Nothing matched your search.", systemImage: "magnifyingglass")
        } else {
            List {
                if !results.forums.isEmpty {
                    Section("Forums") {
                        ForEach(results.forums) { topic in
                            ForumTopicRow(topic: topic)
                        }
                    }
                }
                if !results.apps.isEmpty {
                    Section("Apps") {
                        ForEach(results.apps) { app in
                            AppListingRow(app: app)
                        }
                    }
                }
                if !results.guides.isEmpty {
                    Section("Guides") {
                        ForEach(results.guides) { guide in
                            ResourceRow(resource: guide)
                        }
                    }
                }
                if !results.blogs.isEmpty {
                    Section("Blogs") {
                        ForEach(results.blogs) { post in
                            BlogPostRow(post: post)
                        }
                    }
                }
                if !results.podcasts.isEmpty {
                    Section("Podcasts") {
                        ForEach(results.podcasts) { episode in
                            PodcastEpisodeRow(episode: episode)
                        }
                    }
                }
                if !results.bugs.isEmpty {
                    Section("Bug Reports") {
                        ForEach(results.bugs) { bug in
                            NavigationLink(value: bug) {
                                BugReportRow(bug: bug)
                            }
                        }
                    }
                }
            }
        }
    }
}
