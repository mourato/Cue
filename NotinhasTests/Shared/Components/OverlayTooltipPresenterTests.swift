//
//  OverlayTooltipPresenterTests.swift
//  NotinhasTests
//

@testable import Notinhas
import XCTest

@MainActor
final class OverlayTooltipPresenterTests: XCTestCase {
    private var presenter: OverlayTooltipPresenter!
    private var activeOwner: UUID?

    override func setUp() async throws {
        try await super.setUp()
        presenter = OverlayTooltipPresenter.shared
        activeOwner = nil
    }

    override func tearDown() async throws {
        if let activeOwner {
            presenter.hide(owner: activeOwner)
        }
        activeOwner = nil
        try await super.tearDown()
    }

    func testHide_onlyHidesForMatchingOwner() {
        let ownerA = UUID()
        let ownerB = UUID()
        let content = OverlayTooltipContent(title: "Test", keys: ["R"])
        let anchor = CGRect(x: 200, y: 200, width: 40, height: 28)

        presenter.show(content, anchorScreenFrame: anchor, preferred: .below, owner: ownerA)
        activeOwner = ownerA
        XCTAssertEqual(presenter.testingCurrentOwner, ownerA)

        presenter.hide(owner: ownerB)
        XCTAssertEqual(presenter.testingCurrentOwner, ownerA, "hide from non-owner must not clear tooltip")

        presenter.hide(owner: ownerA)
        activeOwner = nil
        XCTAssertNil(presenter.testingCurrentOwner, "hide from current owner must clear tooltip")
    }

    func testShow_replacingOwnerIgnoresStaleHide() {
        let ownerShown = UUID()
        let ownerNext = UUID()
        let content = OverlayTooltipContent(title: "Shown", keys: ["R"])
        let anchor = CGRect(x: 200, y: 200, width: 40, height: 28)

        presenter.show(content, anchorScreenFrame: anchor, preferred: .below, owner: ownerShown)
        activeOwner = ownerShown
        XCTAssertEqual(presenter.testingCurrentOwner, ownerShown)

        presenter.show(content, anchorScreenFrame: anchor, preferred: .below, owner: ownerNext)
        activeOwner = ownerNext
        XCTAssertEqual(presenter.testingCurrentOwner, ownerNext)

        presenter.hide(owner: ownerShown)
        XCTAssertEqual(
            presenter.testingCurrentOwner,
            ownerNext,
            "stale owner must not clear a newer successful show",
        )
    }
}
