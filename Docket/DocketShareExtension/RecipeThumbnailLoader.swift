import Foundation
import UIKit

nonisolated enum RecipeThumbnailLoader {
    private static let maximumDownloadSize = 10_000_000
    private static let maximumDimension: CGFloat = 1_800
    private static let compressionQuality: CGFloat = 0.82

    static func preparedData(for url: URL?) async -> Data? {
        guard let url else { return nil }

        var request = URLRequest(url: url, timeoutInterval: 12)
        request.setValue("image/avif,image/webp,image/*,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 Version/26.0 Mobile/15E148 Safari/604.1",
            forHTTPHeaderField: "User-Agent"
        )

        do {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 12
            configuration.timeoutIntervalForResource = 15
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            let session = URLSession(configuration: configuration)
            let (data, response) = try await session.data(for: request)
            guard
                let response = response as? HTTPURLResponse,
                (200...299).contains(response.statusCode),
                response.mimeType?.lowercased().hasPrefix("image/") == true,
                !data.isEmpty,
                data.count <= maximumDownloadSize
            else { return nil }
            return prepare(data)
        } catch {
            return nil
        }
    }

    private static func prepare(_ data: Data) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longestSide = max(image.size.width, image.size.height)
        guard longestSide > 0 else { return nil }
        let scale = min(1, maximumDimension / longestSide)
        let targetSize = CGSize(
            width: max(1, (image.size.width * scale).rounded()),
            height: max(1, (image.size.height * scale).rounded())
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return rendered.jpegData(compressionQuality: compressionQuality)
    }
}
