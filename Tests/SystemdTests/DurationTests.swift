#if os(Linux)
    import XCTest

    @testable import Systemd

    final class DurationTests: XCTestCase {
        func testWholeSeconds() {
            XCTAssertEqual(Duration.seconds(1).sdBusMicroseconds, 1_000_000)
            XCTAssertEqual(Duration.seconds(25).sdBusMicroseconds, 25_000_000)
        }

        func testFractions() {
            XCTAssertEqual(Duration.milliseconds(1500).sdBusMicroseconds, 1_500_000)
            XCTAssertEqual(Duration.seconds(0.25).sdBusMicroseconds, 250_000)
            XCTAssertEqual(Duration.microseconds(1).sdBusMicroseconds, 1)
        }

        func testSubMicrosecondsRoundUp() {
            XCTAssertEqual(Duration.nanoseconds(1).sdBusMicroseconds, 1)
            XCTAssertEqual(Duration.nanoseconds(1_000_001).sdBusMicroseconds, 1001)
        }

        func testNonPositiveIsNotTheDefault() {
            XCTAssertEqual(Duration.zero.sdBusMicroseconds, 1)
            XCTAssertEqual(Duration.seconds(-1).sdBusMicroseconds, 1)
        }

        func testOverflowIsNoTimeout() {
            XCTAssertEqual(Duration.seconds(Int64.max).sdBusMicroseconds, .max)
        }
    }
#endif
