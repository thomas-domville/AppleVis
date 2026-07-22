import SwiftUI

struct BugDetailView: View {
    let bugId: String
    @State private var detail: BugReportDetail?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        Group {
            if isLoading && detail == nil {
                LoadingView()
            } else if let err = error, detail == nil {
                ErrorView(message: err) { await load() }
            } else if let detail {
                content(detail)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    @ViewBuilder
    private func content(_ detail: BugReportDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Status banner
                statusBanner(detail).padding(.horizontal)

                // Title
                Text(detail.title)
                    .font(.title2).fontWeight(.semibold)
                    .padding(.horizontal)

                // Metadata
                metaGrid(detail).padding(.horizontal)

                Divider()

                // Description
                if !detail.body.isEmpty {
                    sectionHeading("Description")
                    HTMLTextView(html: detail.body).padding(.horizontal)
                }

                if let steps = detail.stepsToReproduce, !steps.isEmpty {
                    sectionHeading("Steps to Reproduce")
                    HTMLTextView(html: steps).padding(.horizontal)
                }

                if let workaround = detail.workaround, !workaround.isEmpty {
                    sectionHeading("Workaround")
                    HTMLTextView(html: workaround).padding(.horizontal)
                }

                Divider()

                // Comments
                commentsSection(detail)

                Color.clear.frame(height: 40)
            }
            .padding(.vertical)
        }
    }

    private func statusBanner(_ detail: BugReportDetail) -> some View {
        HStack(spacing: 10) {
            Image(systemName: detail.status == .active ? "exclamationmark.circle.fill" : "checkmark.circle.fill")
                .foregroundStyle(detail.status == .active ? .orange : .green)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(detail.status.displayName) · \(detail.severity.displayName) severity")
                    .font(.subheadline).fontWeight(.semibold)
                Text(detail.platform.displayName)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(
            (detail.status == .active ? Color.orange : Color.green).opacity(0.1),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(detail.status.displayName) bug on \(detail.platform.displayName). " +
            "\(detail.severity.displayName) severity."
        )
    }

    private func metaGrid(_ detail: BugReportDetail) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let firstSeen = detail.firstSeen {
                metaRow(label: "First Seen", value: firstSeen)
            }
            if let fixedIn = detail.fixedIn {
                metaRow(label: "Fixed In", value: fixedIn)
            }
            if let device = detail.device, !device.isEmpty {
                metaRow(label: "Device", value: device)
            }
            if let howOften = detail.howOften, !howOften.isEmpty {
                metaRow(label: "How Often", value: howOften)
            }
            metaRow(label: "Reported", value: detail.createdAt.formatted(.relative(presentation: .named)))
            metaRow(label: "Updated", value: detail.changedAt.formatted(.relative(presentation: .named)))
        }
    }

    private func metaRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .font(.caption).fontWeight(.semibold).foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption)
        }
    }

    private func sectionHeading(_ text: String) -> some View {
        Text(text).font(.headline)
            .padding(.horizontal)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private func commentsSection(_ detail: BugReportDetail) -> some View {
        Text("\(detail.comments.count) Comment\(detail.comments.count == 1 ? "" : "s")")
            .font(.headline)
            .padding(.horizontal)
            .accessibilityAddTraits(.isHeader)

        if detail.comments.isEmpty {
            Text("No comments yet.")
                .font(.subheadline).foregroundStyle(.secondary)
                .padding(.horizontal)
        } else {
            ForEach(detail.comments) { comment in
                CommentRow(authorName: comment.authorName, body: comment.body, date: comment.createdAt)
                Divider().padding(.leading)
            }
        }
    }

    private func load() async {
        isLoading = true; error = nil
        do {
            detail = try await APIClient.shared.bugReports.detail(id: bugId)
        } catch let e as APIError { error = e.localizedDescription
        } catch { self.error = "Couldn't load bug report." }
        isLoading = false
    }
}
