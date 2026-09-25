import XCTest


final class FuzzyMatchGeneratorTests: XCTestCase {

    private func makeCompany(
        base: String,
        org: String = "ACME GmbH",
        count: Int = 100
    ) -> Company {
        Company(
            id: nil,
            contactIdentifier: "test-\(base)",
            organizationName: org,
            basePhoneE164: base,
            extensionCount: count,
            isEnabled: true,
            updatedAt: Date()
        )
    }

    func testHeuristicA_singleTrailingZero() {
        let entries = FuzzyMatchGenerator.generateEntries(
            for: makeCompany(base: "+495632969970", count: 10)
        )
        XCTAssertEqual(entries.count, 10)
        XCTAssertEqual(entries.first?.e164, "+495632969970")
        XCTAssertEqual(entries.last?.e164, "+495632969979")
    }

    func testHeuristicA_doubleTrailingZero() {
        let entries = FuzzyMatchGenerator.generateEntries(
            for: makeCompany(base: "+4956329699900", count: 100)
        )
        XCTAssertEqual(entries.count, 100)
        XCTAssertEqual(entries.first?.e164, "+4956329699900")
        XCTAssertEqual(entries.last?.e164, "+4956329699999")
    }

    func testHeuristicA_tripleTrailingZeroCappedByCount() {
        let entries = FuzzyMatchGenerator.generateEntries(
            for: makeCompany(base: "+49563296999000", count: 100)
        )
        XCTAssertEqual(entries.count, 100)
        XCTAssertEqual(entries.first?.e164, "+49563296999000")
        XCTAssertEqual(entries.last?.e164, "+49563296999099")
    }

    func testHeuristicB_noTrailingZero() {
        let entries = FuzzyMatchGenerator.generateEntries(
            for: makeCompany(base: "+495632969971", count: 100)
        )
        XCTAssertEqual(entries.count, 100)
        XCTAssertEqual(entries.first?.e164, "+4956329699" + "00")
        XCTAssertEqual(entries.last?.e164, "+4956329699" + "99")
    }

    func testMobilfunk_noEntries() {
        let entries = FuzzyMatchGenerator.generateEntries(
            for: makeCompany(base: "+491701234567")
        )
        XCTAssertTrue(entries.isEmpty)
    }

    func testSondernummer_noEntries() {
        let entries = FuzzyMatchGenerator.generateEntries(
            for: makeCompany(base: "+498001234567")
        )
        XCTAssertTrue(entries.isEmpty)
    }

    func testInternationalesFestnetz_generatesEntries() {
        // US-Nummern (FIXED_LINE_OR_MOBILE) werden seit der Internationalisierung
        // ebenfalls unterstützt: 2-stellige Heuristik ohne Null-Endung.
        let entries = FuzzyMatchGenerator.generateEntries(
            for: makeCompany(base: "+14155552671", count: 100)
        )
        XCTAssertEqual(entries.count, 100)
        XCTAssertEqual(entries.first?.e164, "+141555526" + "00")
        XCTAssertEqual(entries.last?.e164, "+141555526" + "99")
    }

    func testUKMobile_noEntries() {
        let entries = FuzzyMatchGenerator.generateEntries(
            for: makeCompany(base: "+447912345678")
        )
        XCTAssertTrue(entries.isEmpty)
    }

    func testLabelFormat() {
        let label = FuzzyMatchGenerator.makeLabel(for: "CLEANGAS GmbH")
        XCTAssertEqual(label, FuzzyMatchGenerator.labelPrefix + "CLEANGAS GmbH")
        XCTAssertTrue(label.hasSuffix("CLEANGAS GmbH"))
    }

    func testLongOrganizationNameIsTruncated() {
        let longName = String(repeating: "A", count: 200)
        let label = FuzzyMatchGenerator.makeLabel(for: longName)
        XCTAssertLessThanOrEqual(label.count, FuzzyMatchGenerator.maxLabelLength)
        XCTAssertTrue(label.hasSuffix("…"))
    }

    func testEntriesContainCorrectInt64() {
        let entries = FuzzyMatchGenerator.generateEntries(
            for: makeCompany(base: "+495632969970", count: 1)
        )
        XCTAssertEqual(entries.first?.phoneNumber, 495632969970)
    }

    func testEntriesSortedAscending() {
        let entries = FuzzyMatchGenerator.generateEntries(
            for: makeCompany(base: "+4956329699900", count: 100)
        )
        let numbers = entries.map(\.phoneNumber)
        XCTAssertEqual(numbers, numbers.sorted())
    }

    func testShortNumberIsIgnored() {
        let entries = FuzzyMatchGenerator.generateEntries(
            for: makeCompany(base: "+4912345")
        )
        XCTAssertTrue(entries.isEmpty)
    }
}
