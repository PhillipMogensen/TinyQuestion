import Foundation

enum OllamaError: LocalizedError {
    case unreachable(URL)
    case httpStatus(Int)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .unreachable(let url):
            return "Couldn't reach Ollama at \(url.host ?? "localhost"):\(url.port ?? 11434). Is `ollama serve` running?"
        case .httpStatus(let code):
            return "Ollama responded with HTTP \(code)."
        case .decoding(let err):
            return "Couldn't decode Ollama response: \(err.localizedDescription)"
        }
    }
}

struct OllamaClient {
    let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://localhost:11434")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - List models

    private struct TagsResponse: Decodable {
        struct Model: Decodable { let name: String }
        let models: [Model]
    }

    func listModels() async throws -> [String] {
        let url = baseURL.appendingPathComponent("api/tags")
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url)
        } catch {
            throw OllamaError.unreachable(baseURL)
        }
        try Self.checkStatus(response)
        do {
            return try JSONDecoder().decode(TagsResponse.self, from: data).models.map(\.name)
        } catch {
            throw OllamaError.decoding(error)
        }
    }

    // MARK: - Streaming chat

    private struct ChatRequest: Encodable {
        let model: String
        let messages: [ChatMessage]
        let stream: Bool
    }

    private struct ChatChunk: Decodable {
        struct Message: Decodable { let content: String }
        let message: Message?
        let done: Bool
    }

    /// Streams the assistant's response token-by-token.
    /// Yields each delta string as it arrives. Throws on transport / HTTP errors.
    func streamChat(messages: [ChatMessage], model: String) -> AsyncThrowingStream<String, Error> {
        let url = baseURL.appendingPathComponent("api/chat")
        let body = ChatRequest(model: model, messages: messages, stream: true)

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try JSONEncoder().encode(body)

                    let (bytes, response): (URLSession.AsyncBytes, URLResponse)
                    do {
                        (bytes, response) = try await session.bytes(for: request)
                    } catch {
                        throw OllamaError.unreachable(baseURL)
                    }
                    try Self.checkStatus(response)

                    let decoder = JSONDecoder()
                    for try await line in bytes.lines {
                        guard !line.isEmpty, let data = line.data(using: .utf8) else { continue }
                        let chunk: ChatChunk
                        do {
                            chunk = try decoder.decode(ChatChunk.self, from: data)
                        } catch {
                            throw OllamaError.decoding(error)
                        }
                        if let delta = chunk.message?.content, !delta.isEmpty {
                            continuation.yield(delta)
                        }
                        if chunk.done { break }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Helpers

    private static func checkStatus(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw OllamaError.httpStatus(http.statusCode)
        }
    }
}
