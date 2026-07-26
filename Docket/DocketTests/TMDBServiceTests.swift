import Foundation
import XCTest

@testable import Docket

final class TMDBServiceTests: XCTestCase {
    func testSearchResultDecodesMovieMetadata() throws {
        let data = Data(
            """
            {
              "id": 949,
              "title": "Heat",
              "original_title": "Heat",
              "overview": "A professional thief and a detective cross paths.",
              "release_date": "1995-12-15",
              "poster_path": "/rrBuGu0Pjq7Y2BWSI6teGfZzviY.jpg"
            }
            """.utf8
        )

        let movie = try JSONDecoder().decode(TMDBMovieSummary.self, from: data)

        XCTAssertEqual(movie.id, 949)
        XCTAssertEqual(movie.title, "Heat")
        XCTAssertEqual(movie.releaseYear, 1995)
        XCTAssertEqual(movie.subtitle, "1995")
    }

    func testSearchResultSubtitleIncludesDifferentOriginalTitle() throws {
        let data = Data(
            """
            {
              "id": 1,
              "title": "Spirited Away",
              "original_title": "千と千尋の神隠し",
              "overview": "",
              "release_date": "2001-07-20",
              "poster_path": null
            }
            """.utf8
        )

        let movie = try JSONDecoder().decode(TMDBMovieSummary.self, from: data)

        XCTAssertEqual(movie.subtitle, "2001 · 千と千尋の神隠し")
        XCTAssertNil(movie.posterThumbnailURL)
    }

    func testPosterURLNormalizesLeadingSlash() {
        XCTAssertEqual(
            TMDBService.posterURL(path: "/poster.jpg", size: "w500")?.absoluteString,
            "https://image.tmdb.org/t/p/w500/poster.jpg"
        )
        XCTAssertEqual(
            TMDBService.posterURL(path: "poster.jpg", size: "w185")?.absoluteString,
            "https://image.tmdb.org/t/p/w185/poster.jpg"
        )
    }

    func testFullResolutionPosterURLRequestsOriginalSize() {
        XCTAssertEqual(
            TMDBService.fullResolutionPosterURL(path: "/poster.jpg")?.absoluteString,
            "https://image.tmdb.org/t/p/original/poster.jpg"
        )
        XCTAssertNil(TMDBService.fullResolutionPosterURL(path: nil))
        XCTAssertNil(TMDBService.fullResolutionPosterURL(path: ""))
    }
}
