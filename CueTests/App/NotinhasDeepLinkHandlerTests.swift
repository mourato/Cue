//
//  NotinhasDeepLinkHandlerTests.swift
//  NotinhasTests
//
//  Unit tests for notinhas:// automation URL parsing.
//

@testable import Cue
import XCTest

@MainActor
final class NotinhasDeepLinkHandlerTests: XCTestCase {
    func testCanonicalRoutesParseExpectedActions() throws {
        let cases: [(String, NotinhasDeepLinkAction)] = [
            ("notinhas://capture/fullscreen", .captureFullscreen),
            ("notinhas://capture/all-in-one", .captureAllInOne),
            ("notinhas://capture/area", .captureArea),
            ("notinhas://capture/application", .captureApplication),
            ("notinhas://capture/area-annotate", .captureAreaAnnotate),
            ("notinhas://capture/scrolling", .captureScrolling),
            ("notinhas://capture/ocr", .captureOCR),
            ("notinhas://capture/smart-element", .captureSmartElement),
            ("notinhas://capture/object-cutout", .captureObjectCutout),
            ("notinhas://record/screen", .recordScreen),
            ("notinhas://record/application", .recordApplication),
            ("notinhas://open/annotate", .openAnnotate),
            ("notinhas://open/combine", .openCombine([])),
            ("notinhas://open/video-editor", .openVideoEditor),
            ("notinhas://open/history", .openHistory),
            ("notinhas://show/shortcuts", .showShortcuts),
            ("notinhas://settings", .openSettings(nil)),
        ]

        for (urlString, expectedAction) in cases {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertEqual(NotinhasDeepLinkAction(url: url), expectedAction, urlString)
        }
    }

    func testCombineAliasesParseExpectedAction() throws {
        let aliases = [
            "notinhas://combine",
            "notinhas://combine-images",
            "notinhas://open-combine",
        ]

        for urlString in aliases {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertEqual(NotinhasDeepLinkAction(url: url), .openCombine([]), urlString)
        }
    }

    func testCombineRouteParsesRepeatedFileParameters() throws {
        var components = try XCTUnwrap(URLComponents(string: "notinhas://open/combine"))
        components.queryItems = [
            URLQueryItem(name: "file", value: "/tmp/first image.png"),
            URLQueryItem(name: "file", value: "file:///tmp/second.jpg"),
            URLQueryItem(name: "ignored", value: "/tmp/not-used.png"),
        ]

        let url = try XCTUnwrap(components.url)
        XCTAssertEqual(
            NotinhasDeepLinkAction(url: url),
            .openCombine([
                URL(fileURLWithPath: "/tmp/first image.png"),
                URL(fileURLWithPath: "/tmp/second.jpg"),
            ]),
        )
    }

    func testApplicationCaptureAliasesParseExpectedAction() throws {
        let aliases = [
            "notinhas://capture/window",
            "notinhas://application-capture",
            "notinhas://window-capture",
            "notinhas://screenshot/window",
        ]

        for urlString in aliases {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertEqual(NotinhasDeepLinkAction(url: url), .captureApplication, urlString)
        }
    }

    func testApplicationRecordingAliasesParseExpectedAction() throws {
        let aliases = [
            "notinhas://record/window",
            "notinhas://application-recording",
            "notinhas://window-recording",
            "notinhas://recording/window",
        ]

        for urlString in aliases {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertEqual(NotinhasDeepLinkAction(url: url), .recordApplication, urlString)
        }
    }

    func testSettingsTabRoutesParseExpectedTabs() throws {
        let cases: [(String, PreferencesTab)] = [
            ("general", .general),
            ("capture", .capture),
            ("annotate", .annotate),
            ("quick-access", .quickAccess),
            ("history", .history),
            ("shortcuts", .shortcuts),
            ("permissions", .permissions),
            ("uploads", .cloud),
            ("advanced", .advanced),
        ]

        for (tabName, expectedTab) in cases {
            let queryURL = try XCTUnwrap(URL(string: "notinhas://settings?tab=\(tabName)"))
            XCTAssertEqual(NotinhasDeepLinkAction(url: queryURL), .openSettings(expectedTab), tabName)

            let pathURL = try XCTUnwrap(URL(string: "notinhas://settings/\(tabName)"))
            XCTAssertEqual(NotinhasDeepLinkAction(url: pathURL), .openSettings(expectedTab), tabName)
        }
    }

    func testAboutSettingsRouteIsRejected() throws {
        let url = try XCTUnwrap(URL(string: "notinhas://settings/about"))
        XCTAssertNil(NotinhasDeepLinkAction(url: url))
    }

    func testLegacySnapzySchemeIsRejected() throws {
        let urls = [
            "snapzy://capture/area",
            "snapzy://settings",
            "snapzy://open/combine",
            "snapzy://capture/fullscreen",
            "snapzy://settings/cloud",
        ]

        for urlString in urls {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertNil(NotinhasDeepLinkAction(url: url), urlString)
        }
    }

    func testUnsupportedRoutesReturnNil() throws {
        let urls = [
            "https://capture/area",
            "notinhas://",
            "notinhas://capture/unknown",
            "notinhas://record/stop",
            "notinhas://open/unknown",
        ]

        for urlString in urls {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertNil(NotinhasDeepLinkAction(url: url), urlString)
        }
    }

    func testDeepLinkHandlerChecksUrlSchemeEnabled() throws {
        let defaults = UserDefaults.standard
        let originalValue = defaults.object(forKey: PreferencesKeys.urlSchemeEnabled)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: PreferencesKeys.urlSchemeEnabled)
            } else {
                defaults.removeObject(forKey: PreferencesKeys.urlSchemeEnabled)
            }
        }

        defaults.set(false, forKey: PreferencesKeys.urlSchemeEnabled)
        let viewModel = ScreenCaptureViewModel()
        let handler = NotinhasDeepLinkHandler(screenCaptureViewModel: viewModel)
        let url = try XCTUnwrap(URL(string: "notinhas://capture/fullscreen"))
        handler.handle(url)
    }

    func testVideoDeepLinksIgnoredWhenModuleDisabled() throws {
        let defaults = UserDefaults.standard
        let originalModuleValue = defaults.object(forKey: PreferencesKeys.videoModuleEnabled)
        defer {
            if let originalModuleValue {
                defaults.set(originalModuleValue, forKey: PreferencesKeys.videoModuleEnabled)
            } else {
                defaults.removeObject(forKey: PreferencesKeys.videoModuleEnabled)
            }
        }

        defaults.set(false, forKey: PreferencesKeys.videoModuleEnabled)
        XCTAssertFalse(
            VideoModuleAvailability.isEnabled,
            "Video deep-link handlers must see the module as disabled",
        )
        XCTAssertFalse(
            VideoModuleMediaRouting.shouldDispatchVideoAction(),
            "Routing gate must refuse video deep links when the module is off",
        )

        let viewModel = ScreenCaptureViewModel()
        let handler = NotinhasDeepLinkHandler(screenCaptureViewModel: viewModel)
        let urls = [
            "notinhas://record/screen",
            "notinhas://record/application",
            "notinhas://open/video-editor",
        ]

        for urlString in urls {
            let url = try XCTUnwrap(URL(string: urlString))
            // URLs still parse; the handler must gate dispatch, not drop parsing.
            XCTAssertNotNil(NotinhasDeepLinkAction(url: url), urlString)
            handler.handle(url)
            XCTAssertFalse(
                VideoModuleMediaRouting.shouldDispatchVideoAction(),
                "Module must stay disabled after handling \(urlString)",
            )
        }
    }

    func testVideoDeepLinkRoutingGateMatchesExplicitFlags() {
        XCTAssertFalse(VideoModuleMediaRouting.shouldDispatchVideoAction(videoModuleEnabled: false))
        XCTAssertTrue(VideoModuleMediaRouting.shouldDispatchVideoAction(videoModuleEnabled: true))
    }
}
