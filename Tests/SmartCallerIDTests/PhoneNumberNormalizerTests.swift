import XCTest


final class PhoneNumberNormalizerTests: XCTestCase {

    func testGermanLandlineVariants() {
        // Region explizit setzen: die Default-Region ist jetzt die Geräteregion,
        // im Test-Simulator meist US.
        let n = PhoneNumberNormalizer.shared
        XCTAssertEqual(n.normalize("05632 969970", defaultRegion: "DE"), "+495632969970")
        XCTAssertEqual(n.normalize("05632/96 99 70", defaultRegion: "DE"), "+495632969970")
        XCTAssertEqual(n.normalize("+49 5632 969970", defaultRegion: "DE"), "+495632969970")
        XCTAssertEqual(n.normalize("00495632969970", defaultRegion: "DE"), "+495632969970")
    }

    func testUSNumberWithUSRegion() {
        let n = PhoneNumberNormalizer.shared
        XCTAssertEqual(n.normalize("(415) 555-2671", defaultRegion: "US"), "+14155552671")
        XCTAssertEqual(n.normalize("+1 415 555 2671", defaultRegion: "DE"), "+14155552671")
    }

    func testInvalidInputs() {
        let n = PhoneNumberNormalizer.shared
        XCTAssertNil(n.normalize(""))
        XCTAssertNil(n.normalize("   "))
        XCTAssertNil(n.normalize("abc"))
        XCTAssertNil(n.normalize("*123#"))
    }

    func testAlreadyE164() {
        let n = PhoneNumberNormalizer.shared
        XCTAssertEqual(n.normalize("+4956329699970"), "+4956329699970")
    }
}
