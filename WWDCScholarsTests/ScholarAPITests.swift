//
//  ScholarAPITests.swift
//  WWDCScholars
//
//  Created by Matthijs Logemann on 12/04/16.
//  Copyright © 2016 WWDCScholars. All rights reserved.
//

import XCTest
@testable import WWDCScholars

class ScholarAPITests: XCTestCase {
    
    let scholarApi = ScholarsAPI.sharedInstance
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testALoadScholars() {
        let readyExpectation = expectationWithDescription("ready")
        
        scholarApi.loadScholars() {
            readyExpectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(60, handler: { error in
            XCTAssertNil(error, "Error")
        })
    }
    
    func testBHasScholars() {
        XCTAssertGreaterThan(scholarApi.dbManager.scholarCount(), 0)
    }
    
    func testCShowScholars() {
        XCTAssertEqual(scholarApi.dbManager.scholarCount(), 6)
    }
    
}