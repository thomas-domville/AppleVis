import SwiftUI

struct HelpArticleDetailView: View {
    let article: HelpArticle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(article.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                    .padding(.bottom, 12)

                ForEach(article.content) { block in
                    HelpBlockView(block: block)
                        .padding(.horizontal)
                }

                Color.clear.frame(height: 24)
            }
            .padding(.vertical)
        }
        .navigationTitle(article.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct HelpBlockView: View {
    let block: HelpContentBlock

    var body: some View {
        switch block {
        case .heading(let text):
            Text(text)
                .font(.headline)
                .padding(.top, 8).padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)

        case .body(let text):
            Text(text)
                .font(.body)
                .padding(.bottom, 6)

        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(Color.accentColor)
                        Text(item)
                    }
                }
            }
            .padding(.bottom, 8)

        case .steps(let items):
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1)")
                            .font(.caption).fontWeight(.bold)
                            .frame(width: 22, height: 22)
                            .background(Color.accentColor, in: Circle())
                            .foregroundStyle(.white)
                        Text(item)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Step \(index + 1). \(item)")
                }
            }
            .padding(.bottom, 8)

        case .tip(let text):
            Callout(label: "Tip", text: text, color: .green)
        case .note(let text):
            Callout(label: "Note", text: text, color: .blue)
        case .warning(let text):
            Callout(label: "Important", text: text, color: .orange)

        case .faq(let question, let answer):
            VStack(alignment: .leading, spacing: 4) {
                Text(question).font(.body).fontWeight(.semibold)
                Text(answer).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(.bottom, 10)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Question: \(question). Answer: \(answer)")
        }
    }
}

private struct Callout: View {
    let label: String
    let text: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(color)
            Text(text).font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 0).padding(.leading, -1))
        .overlay(alignment: .leading) {
            Rectangle().fill(color).frame(width: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.bottom, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(text)")
    }
}
