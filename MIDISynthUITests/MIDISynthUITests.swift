//
//  MIDISynthUITests.swift
//  MIDISynthUITests
//
//  Created by Gene De Lisa on 12/11/17.
//  Copyright © 2017 Gene De Lisa. All rights reserved.
//

import XCTest
@testable import MIDISynth

class MIDISynthUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        super.setUp()

        setupSnapshot(app)
        continueAfterFailure = false
        app.launchArguments.append("--uitesting")
        app.launch()
        snapshot("InitialScreen")
    }

    override func tearDown() {
        super.tearDown()
        app.terminate()
    }

    func testMainScreen() {
        let patch1Button = app.buttons["Patch 1"]
        patch1Button.tap()
        let patch2Button = app.buttons["Patch 2"]
        patch2Button.tap()
        app.buttons["Sequence"].tap()
    }

}
