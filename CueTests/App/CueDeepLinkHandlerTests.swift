//
//  CueDeepLinkHandlerTests.swift
//  CueTests
//
//  Unit tests for cue:// automation URL parsing.
//

@testable import Cue
import XCTest

@MainActor
final class CueDeepLinkHandlerTests: XCTestCase {
    func testCanonicalRoutesParseExpectedActions() throws {
        let cases: [(String, CueDeepLinkAction)] = [
            ("cue://capture/fullscreen", .captureFullscreen),
            ("cue://capture/all-in-one", .captureAllInOne),
            ("cue://capture/area", .captureArea),
            ("cue://capture/application", .captureApplication),
            ("cue://capture/area-annotate", .captureAreaAnnotate),
            ("cue://capture/scrolling", .captureScrolling),
            ("cue://capture/ocr", .captureOCR),
            ("cue://capture/smart-element", .captureSmartElement),
            ("cue://capture/object-cutout", .captureObjectCutout),
            ("cue://record/screen", .recordScreen),
            ("cue://record/application", .recordApplication),
            ("cue://open/annotate", .openAnnotate),
            ("cue://open/combine", .openCombine([])),
            ("cue://open/video-editor", .openVideoEditor),
            ("cue://open/history", .openHistory),
            ("cue://show/shortcuts", .showShortcuts),
            ("cue://settings", .openSettings(nil)),
        ]

        for (urlString, expectedAction) in cases {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertEqual(CueDeepLinkAction(url: url), expectedAction, urlString)
        }
    }

    func testCombineAliasesParseExpectedAction() throws {
        let aliases = [
            "cue://combine",
            "cue://combine-images",
            "cue://open-combine",
        ]

        for urlString in aliases {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertEqual(CueDeepLinkAction(url: url), .openCombine([]), urlString)
        }
    }

    func testCombineRouteParsesRepeatedFileParameters() throws {
        var components = try XCTUnwrap(URLComponents(string: "cue://open/combine"))
        components.queryItems = [
            URLQueryItem(name: "file", value: "/tmp/first image.png"),
            URLQueryItem(name: "file", value: "file:///tmp/second.jpg"),
            URLQueryItem(name: "ignored", value: "/tmp/not-used.png"),
        ]

        let url = try XCTUnwrap(components.url)
        XCTAssertEqual(
            CueDeepLinkAction(url: url),
            .openCombine([
                URL(fileURLWithPath: "/tmp/first image.png"),
                URL(fileURLWithPath: "/tmp/second.jpg"),
            ]),
        )
    }

    func testApplicationCaptureAliasesParseExpectedAction() throws {
        let aliases = [
            "cue://capture/window",
            "cue://application-capture",
            "cue://window-capture",
            "cue://screenshot/window",
        ]

        for urlString in aliases {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertEqual(CueDeepLinkAction(url: url), .captureApplication, urlString)
        }
    }

    func testApplicationRecordingAliasesParseExpectedAction() throws {
        let aliases = [
            "cue://record/window",
            "cue://application-recording",
            "cue://window-recording",
            "cue://recording/window",
        ]

        for urlString in aliases {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertEqual(CueDeepLinkAction(url: url), .recordApplication, urlString)
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
            let queryURL = try XCTUnwrap(URL(string: "cue://settings?tab=\(tabName)"))
            XCTAssertEqual(CueDeepLinkAction(url: queryURL), .openSettings(expectedTab), tabName)

            let pathURL = try XCTUnwrap(URL(string: "cue://settings/\(tabName)"))
            XCTAssertEqual(CueDeepLinkAction(url: pathURL), .openSettings(expectedTab), tabName)
        }
    }

    func testAboutSettingsRouteIsRejected() throws {
        let url = try XCTUnwrap(URL(string: "cue://settings/about"))
        XCTAssertNil(CueDeepLinkAction(url: url))
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
            XCTAssertNil(CueDeepLinkAction(url: url), urlString)
        }
    }

    func testLegacyNotinhasSchemeIsRejected() throws {
        let urls = [
            "notinhas://capture/area",
            "notinhas://settings",
            "notinhas://open/combine",
            "notinhas://capture/fullscreen",
            "notinhas://settings/cloud",
        ]

        for urlString in urls {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertNil(CueDeepLinkAction(url: url), urlString)
        }
    }

    func testUnsupportedRoutesReturnNil() throws {
        let urls = [
            "https://capture/area",
            "cue://",
            "cue://capture/unknown",
            "cue://record/stop",
            "cue://open/unknown",
        ]

        for urlString in urls {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertNil(CueDeepLinkAction(url: url), urlString)
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
        let handler = CueDeepLinkHandler(screenCaptureViewModel: viewModel)
        let url = try XCTUnwrap(URL(string: "cue://capture/fullscreen"))
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
        let handler = CueDeepLinkHandler(screenCaptureViewModel: viewModel)
        let urls = [
            "cue://record/screen",
            "cue://record/application",
            "cue://open/video-editor",
        ]

        for urlString in urls {
            let url = try XCTUnwrap(URL(string: urlString))
            XCTAssertNotNil(CueDeepLinkAction(url: url), urlString)
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
