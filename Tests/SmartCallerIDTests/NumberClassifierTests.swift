import XCTest


final class NumberClassifierTests: XCTestCase {

    // MARK: - Deutschland (+49)

    func testDeutschesFestnetz() {
        XCTAssertEqual(NumberClassifier.classify("+495632969970"), .festnetz)
        XCTAssertEqual(NumberClassifier.classify("+493012345678"), .festnetz)
        XCTAssertEqual(NumberClassifier.classify("+49221456789"), .festnetz)
    }

    func testDeutscherMobilfunk() {
        XCTAssertEqual(NumberClassifier.classify("+491701234567"), .mobilfunk)
        XCTAssertEqual(NumberClassifier.classify("+491521234567"), .mobilfunk)
        XCTAssertEqual(NumberClassifier.classify("+491631234567"), .mobilfunk)
    }

    func testDeutscheSondernummern() {
        XCTAssertEqual(NumberClassifier.classify("+498001234567"), .sondernummer)
        XCTAssertEqual(NumberClassifier.classify("+491801234567"), .sondernummer)
        XCTAssertEqual(NumberClassifier.classify("+499001234567"), .sondernummer)
    }

    // MARK: - International (via libPhoneNumber)

    func testInternationalesFestnetz() {
        // USA: NANP-Nummern sind FIXED_LINE_OR_MOBILE → wie Festnetz behandelt
        XCTAssertEqual(NumberClassifier.classify("+14155552671"), .festnetz)
        // Schweiz: Zürich Festnetz
        XCTAssertEqual(NumberClassifier.classify("+41441234567"), .festnetz)
        // Österreich: Wien Festnetz
        XCTAssertEqual(NumberClassifier.classify("+4315877690"), .festnetz)
    }

    func testInternationalerMobilfunk() {
        // UK Mobile
        XCTAssertEqual(NumberClassifier.classify("+447912345678"), .mobilfunk)
        // Österreich Mobile
        XCTAssertEqual(NumberClassifier.classify("+436641234567"), .mobilfunk)
    }

    func testInternationaleSondernummern() {
        // US Toll-Free
        XCTAssertEqual(NumberClassifier.classify("+18002751234"), .sondernummer)
    }

    func testUngueltig() {
        XCTAssertEqual(NumberClassifier.classify("ohne-plus"), .ungueltig)
        XCTAssertEqual(NumberClassifier.classify("+49abc"), .ungueltig)
        XCTAssertEqual(NumberClassifier.classify("+491234"), .ungueltig)
    }

    func testFuzzySupport() {
        XCTAssertTrue(PhoneNumberCategory.festnetz.supportsFuzzyMatch)
        XCTAssertFalse(PhoneNumberCategory.mobilfunk.supportsFuzzyMatch)
        XCTAssertFalse(PhoneNumberCategory.sondernummer.supportsFuzzyMatch)
        XCTAssertFalse(PhoneNumberCategory.ungueltig.supportsFuzzyMatch)
    }
}
