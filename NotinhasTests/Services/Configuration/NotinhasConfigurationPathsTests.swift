//
//  NotinhasConfigurationPathsTests.swift
//  NotinhasTests
//
//  Tests for user-managed TOML configuration paths.
//

import Darwin
@testable import Notinhas
import XCTest

@MainActor
final class NotinhasConfigurationPathsTests: XCTestCase {
    func testSuggestedConfigURLUsesProvidedHomeDirectory() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        let url = NotinhasConfigurationPaths.suggestedConfigURL(homeDirectory: home)

        XCTAssertEqual(url.path, "/Users/example/.config/notinhas/config.toml")
    }

    func testSuggestedConfigDirectoryURLUsesProvidedHomeDirectory() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        let url = NotinhasConfigurationPaths.suggestedConfigDirectoryURL(homeDirectory: home)

        XCTAssertEqual(url.path, "/Users/example/.config/notinhas")
    }

    func testCollapsingHomePathConvertsAbsolutePathToTilde() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        XCTAssertEqual(
            NotinhasConfigurationPaths.collapsingHomePath("/Users/example/Desktop", homeDirectory: home),
            "~/Desktop",
        )
        XCTAssertEqual(
            NotinhasConfigurationPaths.collapsingHomePath("/Users/example", homeDirectory: home),
            "~",
        )
        XCTAssertEqual(
            NotinhasConfigurationPaths.collapsingHomePath("/tmp/snapzy", homeDirectory: home),
            "/tmp/snapzy",
        )
    }

    func testExpandedUserPathUsesProvidedHomeDirectory() {
        let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

        XCTAssertEqual(
            NotinhasConfigurationPaths.expandedUserPath("~/Desktop", homeDirectory: home),
            "/Users/example/Desktop",
        )
        XCTAssertEqual(
            NotinhasConfigurationPaths.expandedUserPath("/tmp/snapzy", homeDirectory: home),
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
        let expectedURL = NotinhasConfigurationPaths.suggestedConfigURL(homeDirectory: expectedHome)

        XCTAssertEqual(NotinhasConfigurationService.shared.suggestedConfigURL.path, expectedURL.path)
    }
}
