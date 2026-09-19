//
//  OverlayTooltipPresenterTests.swift
//  NotinhasTests
//

@testable import Cue
import XCTest

@MainActor
final class OverlayTooltipPresenterTests: XCTestCase {
    private var presenter: OverlayTooltipPresenter!

    override func setUp() async throws {
        try await super.setUp()
        presenter = OverlayTooltipPresenter.shared
        presenter.testingSuppressPresentation = true
    }

    override func tearDown() async throws {
        presenter.dismissImmediately()
        presenter.testingSuppressPresentation = false
        try await super.tearDown()
    }

    func testHide_onlyHidesForMatchingOwner() {
        let ownerA = UUID()
        let ownerB = UUID()
        let content = OverlayTooltipContent(title: "Test", keys: ["R"])
        let anchor = CGRect(x: 200, y: 200, width: 40, height: 28)

        presenter.show(
            content,
            anchorScreenFrame: anchor,
            preferred: .below,
            owner: ownerA,
            token: presenter.presentationToken()
        )
        XCTAssertEqual(presenter.testingCurrentOwner, ownerA)

        presenter.hide(owner: ownerB)
        XCTAssertEqual(presenter.testingCurrentOwner, ownerA, "hide from non-owner must not clear tooltip")

        presenter.hide(owner: ownerA)
        XCTAssertNil(presenter.testingCurrentOwner, "hide from current owner must clear tooltip")
    }

    func testShow_replacingOwnerIgnoresStaleHide() {
        let ownerShown = UUID()
        let ownerNext = UUID()
        let content = OverlayTooltipContent(title: "Shown", keys: ["R"])
        let anchor = CGRect(x: 200, y: 200, width: 40, height: 28)

        presenter.show(
            content,
            anchorScreenFrame: anchor,
            preferred: .below,
            owner: ownerShown,
            token: presenter.presentationToken()
        )
        XCTAssertEqual(presenter.testingCurrentOwner, ownerShown)

        presenter.show(
            content,
            anchorScreenFrame: anchor,
            preferred: .below,
            owner: ownerNext,
            token: presenter.presentationToken()
        )
        XCTAssertEqual(presenter.testingCurrentOwner, ownerNext)

        presenter.hide(owner: ownerShown)
        XCTAssertEqual(
            presenter.testingCurrentOwner,
            ownerNext,
            "stale owner must not clear a newer successful show"
        )
    }

    func testDismissImmediately_clearsOwnerAndInvalidatesPendingPresentation() {
        let owner = UUID()
        let content = OverlayTooltipContent(title: "Test")
        let anchor = CGRect(x: 200, y: 200, width: 40, height: 28)
        let token = presenter.presentationToken()

        presenter.show(
            content,
            anchorScreenFrame: anchor,
            preferred: .below,
            owner: owner,
            token: token
        )
        XCTAssertEqual(presenter.testingCurrentOwner, owner)

        presenter.dismissImmediately()
        XCTAssertNil(presenter.testingCurrentOwner)

        presenter.show(
            content,
            anchorScreenFrame: anchor,
            preferred: .below,
            owner: UUID(),
            token: token
        )
        XCTAssertNil(presenter.testingCurrentOwner)
    }
}
