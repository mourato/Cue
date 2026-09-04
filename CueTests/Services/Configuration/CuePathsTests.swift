//
//  CuePathsTests.swift
//  NotinhasTests
//
//  Tests for user-managed TOML configuration paths.
//

@testable import Cue
import Darwin
import XCTest

@MainActor
final class CueConfigurationPathsTests: XCTestCase {
    func testSuggestedConfigURLUsesProvidedHomeDirectory() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        let url = CueConfigurationPaths.suggestedConfigURL(homeDirectory: home)

        XCTAssertEqual(url.path, "/Users/example/.config/cue/config.toml")
    }

    func testSuggestedConfigDirectoryURLUsesProvidedHomeDirectory() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        let url = CueConfigurationPaths.suggestedConfigDirectoryURL(homeDirectory: home)

        XCTAssertEqual(url.path, "/Users/example/.config/cue")
    }

    func testCollapsingHomePathConvertsAbsolutePathToTilde() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        XCTAssertEqual(
            CueConfigurationPaths.collapsingHomePath("/Users/example/Desktop", homeDirectory: home),
            "~/Desktop",
        )
        XCTAssertEqual(
            CueConfigurationPaths.collapsingHomePath("/Users/example", homeDirectory: home),
            "~",
        )
        XCTAssertEqual(
            CueConfigurationPaths.collapsingHomePath("/tmp/snapzy", homeDirectory: home),
            "/tmp/snapzy",
        )
    }

    func testExpandedUserPathUsesProvidedHomeDirectory() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        XCTAssertEqual(
            CueConfigurationPaths.expandedUserPath("~/Desktop", homeDirectory: home),
            "/Users/example/Desktop",
        )
        XCTAssertEqual(
            CueConfigurationPaths.expandedUserPath("/tmp/snapzy", homeDirectory: home),
            "/tmp/snapzy",
        )
    }

    func testSuggestedConfigURLUsesAccountHomeDirectory() throws {
        guard
            let passwd = getpwuid(getuid()),
            let home = passwd.pointee.pw_dir
        else {
            throw XCTSkip("No POSIX home directory is available for the current user.")
        }

        let expectedHome = URL(fileURLWithPath: String(cString: home), isDirectory: true)
        let expectedURL = CueConfigurationPaths.suggestedConfigURL(homeDirectory: expectedHome)

        XCTAssertEqual(CueConfigurationService.shared.suggestedConfigURL.path, expectedURL.path)
    }
}
