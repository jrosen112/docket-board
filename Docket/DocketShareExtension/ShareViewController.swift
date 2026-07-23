import SwiftUI
import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var host: UIHostingController<ShareRootView>?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 20 / 255, green: 24 / 255, blue: 31 / 255, alpha: 1)

        Task { @MainActor in
            let payload = await loadPayload()
            show(payload: payload)
        }
    }

    private func show(payload: SharedRecipePayload?) {
        let root = ShareRootView(
            payload: payload,
            boards: ShareBoardCatalog.load(),
            onCancel: { [weak self] in
                self?.extensionContext?.cancelRequest(withError: ShareExtensionError.cancelled)
            },
            onComplete: { [weak self] in
                self?.extensionContext?.completeRequest(returningItems: nil)
            }
        )
        let host = UIHostingController(rootView: root)
        self.host = host
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        host.didMove(toParent: self)
    }

    private func loadPayload() async -> SharedRecipePayload? {
        guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else { return nil }

        var sharedURL: URL?
        var suggestedTitle: String?
        var captionCandidates: [String] = []

        for inputItem in inputItems {
            if let attributedTitle = inputItem.attributedTitle?.string.nilIfBlank {
                suggestedTitle = suggestedTitle ?? attributedTitle
                if looksLikeCaption(attributedTitle) {
                    captionCandidates.append(attributedTitle)
                }
            }
            if let contentText = inputItem.attributedContentText?.string.nilIfBlank {
                captionCandidates.append(contentText)
            }

            for provider in inputItem.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                    let value = try? await provider.loadItem(
                        forTypeIdentifier: UTType.url.identifier,
                        options: nil
                    ),
                    let url = webURL(from: value),
                    sharedURL == nil
                {
                    sharedURL = url
                }

                for typeIdentifier in textTypeIdentifiers(from: provider) {
                    if let value = try? await provider.loadItem(
                        forTypeIdentifier: typeIdentifier,
                        options: nil
                    ), let text = sharedText(from: value)?.nilIfBlank {
                        captionCandidates.append(text)
                        sharedURL = sharedURL ?? firstWebURL(in: text)
                    }
                }
            }
        }

        guard let sharedURL else { return nil }
        return SharedRecipePayload(
            url: sharedURL,
            suggestedTitle: suggestedTitle,
            caption: caption(from: captionCandidates, excluding: sharedURL)
        )
    }

    private func webURL(from value: NSSecureCoding) -> URL? {
        let url: URL?
        if let sharedURL = value as? URL {
            url = sharedURL
        } else if let sharedURL = value as? NSURL {
            url = sharedURL as URL
        } else if let string = value as? String {
            url = URL(string: string)
        } else {
            url = nil
        }
        guard let url, ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            return nil
        }
        return url
    }

    private func firstWebURL(in text: String) -> URL? {
        text.split(whereSeparator: \Character.isWhitespace)
            .compactMap { token -> URL? in
                let cleaned = token.trimmingCharacters(in: CharacterSet(charactersIn: "()[]{}<>,."))
                return URL(string: cleaned)
            }
            .first { ["http", "https"].contains($0.scheme?.lowercased() ?? "") }
    }

    private func caption(from candidates: [String], excluding url: URL) -> String? {
        candidates
            .map { candidate in
                candidate
                    .replacingOccurrences(of: url.absoluteString, with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter {
                !$0.isEmpty
                    && (firstWebURL(in: $0) == nil
                        || $0.split(whereSeparator: \Character.isWhitespace).count > 1)
            }
            .max(by: { $0.count < $1.count })?
            .nilIfBlank
    }

    private func textTypeIdentifiers(from provider: NSItemProvider) -> [String] {
        var identifiers = provider.registeredTypeIdentifiers.filter { identifier in
            UTType(identifier)?.conforms(to: .text) == true
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            identifiers.insert(UTType.plainText.identifier, at: 0)
        }
        return Array(NSOrderedSet(array: identifiers)) as? [String] ?? identifiers
    }

    private func sharedText(from value: NSSecureCoding) -> String? {
        switch value {
        case let string as String:
            string
        case let string as NSString:
            string as String
        case let attributedString as NSAttributedString:
            attributedString.string
        case let data as Data:
            String(data: data, encoding: .utf8)
        default:
            nil
        }
    }

    private func looksLikeCaption(_ value: String) -> Bool {
        value.count >= 60 || value.contains("\n")
    }
}

extension String {
    fileprivate var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum ShareExtensionError: LocalizedError {
    case cancelled

    var errorDescription: String? { "Share cancelled" }
}
