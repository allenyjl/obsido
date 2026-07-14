import Testing

@Suite struct SmokeTests {
    @Test func testingFrameworkWorks() {
        #expect(1 + 1 == 2)
    }
}
