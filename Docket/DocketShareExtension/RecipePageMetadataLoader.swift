import Foundation

nonisolated enum RecipePageMetadataError: Error {
    case invalidResponse
    case noCaption
}

nonisolated struct RecipePageMetadata: Equatable, Sendable {
    let caption: String
    let imageURL: URL?
}

nonisolated enum RecipePageMetadataLoader {
    private static let maximumHTMLSize = 2_000_000
    private static let maximumOEmbedSize = 256_000

    private struct TikTokOEmbedResponse: Decodable {
        let title: String
        let thumbnailURL: URL?

        private enum CodingKeys: String, CodingKey {
            case title
            case thumbnailURL = "thumbnail_url"
        }
    }

    static func metadata(for url: URL) async throws -> RecipePageMetadata {
        if isTikTokURL(url), let metadata = try? await tiktokMetadata(for: url) {
            return metadata
        }

        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 Version/26.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        request.setValue(Locale.preferredLanguages.first ?? "en", forHTTPHeaderField: "Accept-Language")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 15
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration)

        let (data, response) = try await session.data(for: request)
        guard
            let response = response as? HTTPURLResponse,
            (200...299).contains(response.statusCode),
            !data.isEmpty,
            data.count <= maximumHTMLSize,
            let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
        else {
            throw RecipePageMetadataError.invalidResponse
        }

        guard let metadata = extractMetadata(fromHTML: html, baseURL: url) else {
            throw RecipePageMetadataError.noCaption
        }
        return metadata
    }

    static func decodeTikTokMetadata(from data: Data) -> RecipePageMetadata? {
        guard
            let response = try? JSONDecoder().decode(TikTokOEmbedResponse.self, from: data),
            let caption = response.title.nilIfBlank
        else { return nil }
        return RecipePageMetadata(caption: caption, imageURL: response.thumbnailURL)
    }

    static func extractMetadata(fromHTML html: String, baseURL: URL) -> RecipePageMetadata? {
        let preferredKeys = ["og:description", "twitter:description", "description"]
        var values: [String: String] = [:]
        var imageValues: [String: String] = [:]

        for tag in matches(pattern: #"<meta\b[^>]*>"#, in: html) {
            let attributes = metaAttributes(in: tag)
            guard
                let key = (attributes["property"] ?? attributes["name"])?.lowercased(),
                let content = attributes["content"]?.decodingHTMLEntities.nilIfBlank
            else { continue }
            if preferredKeys.contains(key) {
                values[key] = values[key] ?? content
            } else if key == "og:image" || key == "twitter:image" {
                imageValues[key] = imageValues[key] ?? content
            }
        }

        guard let caption = preferredKeys.compactMap({ values[$0] }).first else { return nil }
        let imageURL =
            structuredThumbnailURL(fromHTML: html, baseURL: baseURL)
            ?? ["twitter:image", "og:image"]
            .compactMap { imageValues[$0] }
            .compactMap { URL(string: $0, relativeTo: baseURL)?.absoluteURL }
            .first { ["http", "https"].contains($0.scheme?.lowercased() ?? "") }
        return RecipePageMetadata(caption: caption, imageURL: imageURL)
    }

    private static func structuredThumbnailURL(fromHTML html: String, baseURL: URL) -> URL? {
        let pattern =
            #"<script\b[^>]*type\s*=\s*[\"']application/ld\+json[\"'][^>]*>(.*?)</script>"#
        guard
            let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            )
        else { return nil }

        let range = NSRange(html.startIndex..., in: html)
        for match in regex.matches(in: html, range: range) {
            guard
                match.numberOfRanges == 2,
                let contentRange = Range(match.range(at: 1), in: html),
                let data = String(html[contentRange]).data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data)
            else { continue }

            for value in thumbnailValues(in: object) {
                guard
                    let url = URL(string: value, relativeTo: baseURL)?.absoluteURL,
                    ["http", "https"].contains(url.scheme?.lowercased() ?? "")
                else { continue }
                return url
            }
        }
        return nil
    }

    private static func tiktokMetadata(for url: URL) async throws -> RecipePageMetadata {
        var components = URLComponents(string: "https://www.tiktok.com/oembed")
        components?.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
        guard let endpoint = components?.url else {
            throw RecipePageMetadataError.invalidResponse
        }

        var request = URLRequest(url: endpoint, timeoutInterval: 12)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 15
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration)
        let (data, response) = try await session.data(for: request)
        guard
            let response = response as? HTTPURLResponse,
            (200...299).contains(response.statusCode),
            !data.isEmpty,
            data.count <= maximumOEmbedSize,
            let metadata = decodeTikTokMetadata(from: data)
        else {
            throw RecipePageMetadataError.invalidResponse
        }
        return metadata
    }

    private static func isTikTokURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "tiktok.com" || host.hasSuffix(".tiktok.com")
    }

    private static func thumbnailValues(in object: Any) -> [String] {
        if let dictionary = object as? [String: Any] {
            var matches: [String] = []
            for (key, value) in dictionary {
                if key.lowercased() == "thumbnailurl" {
                    if let string = value as? String {
                        matches.append(string)
                    } else if let strings = value as? [String] {
                        matches.append(contentsOf: strings)
                    }
                }
            }
            for value in dictionary.values {
                matches.append(contentsOf: thumbnailValues(in: value))
            }
            return matches
        }
        if let array = object as? [Any] {
            return array.flatMap { thumbnailValues(in: $0) }
        }
        return []
    }

    private static func metaAttributes(in tag: String) -> [String: String] {
        let pattern = #"([A-Za-z_:][-A-Za-z0-9_:.]*)\s*=\s*([\"'])(.*?)\2"#
        var attributes: [String: String] = [:]
        guard
            let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            )
        else { return attributes }

        let range = NSRange(tag.startIndex..., in: tag)
        for match in regex.matches(in: tag, range: range) where match.numberOfRanges == 4 {
            guard
                let nameRange = Range(match.range(at: 1), in: tag),
                let valueRange = Range(match.range(at: 3), in: tag)
            else { continue }
            attributes[String(tag[nameRange]).lowercased()] = String(tag[valueRange])
        }
        return attributes
    }

    private static func matches(pattern: String, in value: String) -> [String] {
        guard
            let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .dotMatchesLineSeparators]
            )
        else { return [] }
        let range = NSRange(value.startIndex..., in: value)
        return regex.matches(in: value, range: range).compactMap { match in
            Range(match.range, in: value).map { String(value[$0]) }
        }
    }
}

nonisolated extension String {
    fileprivate var decodingHTMLEntities: String {
        var result = self
        let namedEntities = [
            "&quot;": "\"",
            "&#39;": "'",
            "&apos;": "'",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " ",
        ]
        for (entity, replacement) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }

        guard let regex = try? NSRegularExpression(pattern: #"&#(x?[0-9A-Fa-f]+);"#) else {
            return result
        }
        let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
        for match in matches.reversed() {
            guard
                let fullRange = Range(match.range(at: 0), in: result),
                let numberRange = Range(match.range(at: 1), in: result)
            else { continue }
            let number = String(result[numberRange])
            let radix = number.lowercased().hasPrefix("x") ? 16 : 10
            let digits = radix == 16 ? String(number.dropFirst()) : number
            guard let scalarValue = UInt32(digits, radix: radix), let scalar = UnicodeScalar(scalarValue)
            else { continue }
            result.replaceSubrange(fullRange, with: String(Character(scalar)))
        }
        return result
    }

    fileprivate var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
