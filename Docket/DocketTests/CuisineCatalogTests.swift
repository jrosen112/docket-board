import XCTest

@testable import Docket

final class CuisineCatalogTests: XCTestCase {
    func testNormalizationTrimsDeduplicatesAndUsesDefaultCapitalization() {
        XCTAssertEqual(
            CuisineCatalog.normalized([" thai ", "THAI", "  New   American  "]),
            ["Thai", "New American"]
        )
    }

    func testExistingCustomCuisineJoinsDefaultsAsSuggestion() {
        let available = CuisineCatalog.availableCuisines(
            existing: ["Californian", "thai", "Californian"]
        )

        XCTAssertTrue(available.contains("American"))
        XCTAssertTrue(available.contains("Thai"))
        XCTAssertEqual(available.filter { $0 == "Californian" }.count, 1)
    }

    func testSuggestionsMatchQueryAndExcludeSelectedValues() {
        let suggestions = CuisineCatalog.suggestions(
            matching: "chi",
            selected: ["Chinese"],
            available: ["Chilean"]
        )

        XCTAssertEqual(suggestions, ["Chilean"])
    }
}
