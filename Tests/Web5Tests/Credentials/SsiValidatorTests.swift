import XCTest

@testable import Web5

class SsiValidatorTests: XCTestCase {

    func test_validateContext() throws {
        do {
            try SsiValidator.validate(context: ["http://example.com"])
        } catch let err {
            XCTAssertEqual(err as! SsiValidator.Error, SsiValidator.Error.invalidContext)
        }

        XCTAssertNoThrow(try SsiValidator.validate(context: [CredentialConstant.defaultContext ,"http://example.com"]))
    }

    func test_validateVcType() throws {
        do {
            try SsiValidator.validate(vcType: ["CustomType"])
        } catch let err {
            XCTAssertEqual(err as! SsiValidator.Error, SsiValidator.Error.invalidVCType)
        }

        XCTAssertNoThrow(try SsiValidator.validate(vcType: [CredentialConstant.defaultVcType ,"http://example.com"]))
    }

    func test_validateCredentialSubject() throws {
        do {
            try SsiValidator.validate(credentialSubject: [:])
        } catch let err {
            XCTAssertEqual(err as! SsiValidator.Error, SsiValidator.Error.emptyCredentialSubject)
        }
        XCTAssertNoThrow(try SsiValidator.validate(credentialSubject: ["id":"did:example:123"]))
    }

    func test_validateTimeStamp() throws {
        do {
            try SsiValidator.validate(timestamp: "invalid-timestamp")
        } catch let err {
            XCTAssertEqual(err as! SsiValidator.Error, SsiValidator.Error.invalidTimestamp)
        }
        let validTimestamp = "2022-08-28T12:34:56Z"
        XCTAssertNoThrow(try SsiValidator.validate(timestamp: validTimestamp))
    }
}