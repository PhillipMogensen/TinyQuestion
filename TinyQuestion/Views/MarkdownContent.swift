import SwiftUI

/// Lightweight markdown renderer: splits on triple-backtick fences,
/// renders code blocks as separate styled views, and renders the rest
/// via SwiftUI's built-in inline AttributedString markdown (handles
/// inline code, bold, italics, links).
struct MarkdownContent: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(parse(text).enumerated()), id: \.offset) { _, block in
                switch block {
                case .paragraph(let str):
                    Text(attributed(str))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                case .code(_, let content):
                    Text(content)
                        .font(.system(size: 12.5, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.08))
                        )
                }
            }
        }
    }

    private func attributed(_ source: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace
        )
        return (try? AttributedString(markdown: source, options: options))
            ?? AttributedString(source)
    }
}

private enum Block {
    case paragraph(String)
    case code(language: String?, content: String)
}

private func parse(_ markdown: String) -> [Block] {
    var blocks: [Block] = []
    var buffer: [String] = []
    var inCode = false
    var codeLang: String?

    func flushParagraph() {
        let joined = buffer.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !joined.isEmpty {
            blocks.append(.paragraph(joined))
        }
        buffer.removeAll()
    }

    func flushCode() {
        // Preserve internal whitespace; only trim a trailing newline.
        var joined = buffer.joined(separator: "\n")
        if joined.hasSuffix("\n") { joined.removeLast() }
        blocks.append(.code(language: codeLang, content: joined))
        buffer.removeAll()
        codeLang = nil
    }

    for line in markdown.components(separatedBy: "\n") {
        if line.hasPrefix("```") {
            if inCode {
                flushCode()
                inCode = false
            } else {
                flushParagraph()
                inCode = true
                let lang = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                codeLang = lang.isEmpty ? nil : lang
            }
        } else {
            buffer.append(line)
        }
    }

    if inCode {
        // Unclosed fence (e.g. mid-stream) — render what we have as code.
        flushCode()
    } else {
        flushParagraph()
    }

    return blocks
}
