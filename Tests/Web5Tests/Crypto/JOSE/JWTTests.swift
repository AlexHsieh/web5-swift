import XCTest
import Foundation

@testable import Web5

final class JWTTests: XCTestCase {
    
    func test_sign() throws {
        let did = try DIDJWK.create()

        let claims = JWT.Claims(
            issuer: did.identifier,
            expiration: Date.distantFuture,
            misc: ["nonce": 123]
        )
        let jwt = try JWT.sign(did: did, claims: claims)

        XCTAssertFalse(jwt.isEmpty)
        
        let decoded = try JWT.parse(jwtString: jwt)
        let decodedNonceValue = decoded.payload.miscellaneous?["nonce"]?.value as? Int
        XCTAssertEqual(decodedNonceValue, 123)
        
    }

    func test_parseJwt() throws {
        do {
            _ = try JWT.parse(jwtString: "abcd123")
        } catch let error as JWT.Error {
            XCTAssertEqual(error, JWT.Error.verificationFailed("Malformed JWT. Expected 3 parts. Got 1"))
        }

        do {
            let header = JWS.Header(algorithm: .es256k, keyID: "keyID")
            let base64UrlEncodedHeader = try JSONEncoder().encode(header).base64UrlEncodedString()
             _ = try JWT.parse(jwtString: "\(base64UrlEncodedHeader).efgh.hijk")
        } catch let error as JWT.Error {
            XCTAssertEqual(error, JWT.Error.verificationFailed("Expected JWT header to contain typ property set to JWT"))
        }

        do {
            let header = JWS.Header(algorithm: .es256k, type: "JWT")
            let base64UrlEncodedHeader = try JSONEncoder().encode(header).base64UrlEncodedString()
             _ = try JWT.parse(jwtString: "\(base64UrlEncodedHeader).efgh.hijk")
        } catch let error as JWT.Error {
            XCTAssertEqual(error, JWT.Error.verificationFailed("Expected JWT header to contain kid"))
        }

        // decode payload fails
        let header = JWS.Header(algorithm: .es256k, keyID: "keyID", type: "JWT")
        let base64UrlEncodedHeader = try JSONEncoder().encode(header).base64UrlEncodedString()
        XCTAssertThrowsError(try JWT.parse(jwtString: "\(base64UrlEncodedHeader).efgh.hijk"))
    }

    func test_verifyJwtExpired() async throws {
        let did = try DIDJWK.create(options: .init(algorithm: .secp256k1))
        let header = JWS.Header(algorithm: .es256k, keyID: did.document.verificationMethod!.first!.id, type: "JWT")
        let base64UrlEncodedHeader = try JSONEncoder().encode(header).base64UrlEncodedString()
        let claims = JWT.Claims(expiration: Date(timeIntervalSinceNow: -1))
        let base64UrlEncodedClaims = try JSONEncoder().encode(claims).base64UrlEncodedString()
        do {
             _ = try await JWT.verify(jwt: "\(base64UrlEncodedHeader).\(base64UrlEncodedClaims).hijk")
        } catch let error as JWT.Error {
            XCTAssertEqual(error, JWT.Error.verificationFailed("JWT has expired"))
        }
    }

    func test_verifyJwtKeyIdNotDereferencedVerificationMethod() async throws {
        let did = try DIDJWK.create(options: .init(algorithm: .secp256k1))
        let header = JWS.Header(algorithm: .es256k, keyID: did.uri, type: "JWT")
        let base64UrlEncodedHeader = try JSONEncoder().encode(header).base64UrlEncodedString()
        let claims = JWT.Claims(issuer: did.uri, subject: did.uri, issuedAt: Date())
        let base64UrlEncodedClaims = try JSONEncoder().encode(claims).base64UrlEncodedString()
        do {
             _ = try await JWT.verify(jwt: "\(base64UrlEncodedHeader).\(base64UrlEncodedClaims).hijk")
        } catch let error as JWT.Error {
            XCTAssertEqual(error, JWT.Error.verificationFailed("Expected kid in JWT header to dereference a DID Document Verification Method"))
        }
    }

    func test_verifyPublicKeyAlgorithmIsNotSupported() async throws {
        let did = try DIDJWK.create(options: .init(algorithm: .secp256k1))
        let header = JWS.Header(algorithm: .eddsa, keyID: did.document.verificationMethod!.first!.id, type: "JWT")
        let base64UrlEncodedHeader = try JSONEncoder().encode(header).base64UrlEncodedString()
        let claims = JWT.Claims(issuer: did.uri, subject: did.uri, issuedAt: Date())
        let base64UrlEncodedClaims = try JSONEncoder().encode(claims).base64UrlEncodedString()
        do {
             _ = try await JWT.verify(jwt: "\(base64UrlEncodedHeader).\(base64UrlEncodedClaims).hijk")
        } catch let error as JWT.Error {
            XCTAssertEqual(error, JWT.Error.verificationFailed("Expected alg in JWT header to match DID Document Verification Method alg"))
        }
    }

    func test_verifyReturnDecodedJwt() async throws {
        let did = try DIDJWK.create()
        let portableDid = try did.export()
        let header = JWS.Header(algorithm: .eddsa, keyID: did.document.verificationMethod!.first!.id, type: "JWT")
        let base64UrlEncodedHeader = try JSONEncoder().encode(header).base64UrlEncodedString()
        let claims = JWT.Claims(issuer: did.uri, subject: did.uri, issuedAt: Date())
        let base64UrlEncodedClaims = try JSONEncoder().encode(claims).base64UrlEncodedString()
        let toSign = "\(base64UrlEncodedHeader).\(base64UrlEncodedClaims)"
        let toSignBytes = [UInt8](toSign.utf8)
        let privateKeyJwk = portableDid.privateKeys.first!
        let signatureBytes = try Ed25519.sign(payload: toSignBytes, privateKey: privateKeyJwk)
        let base64UrlEncodedSignature = signatureBytes.base64UrlEncodedString()
        let jwt = "\(toSign).\(base64UrlEncodedSignature)"
        let decoded = try await JWT.verify(jwt: jwt)
        XCTAssertEqual(header.algorithm, decoded.header.algorithm)
        XCTAssertEqual(header.keyID, decoded.header.keyID)
        XCTAssertEqual(claims.issuer, decoded.payload.issuer)
        XCTAssertEqual(claims.subject, decoded.payload.subject)
        XCTAssertEqual(claims.issuedAt, decoded.payload.issuedAt)    
    }
}

// todo consider adding more tests to verify encode and decode works as intended
class JWTClaimsTests: XCTestCase {

    func testClaimsEncodingDecoding() {
        let originalClaims = JWT.Claims(
            issuer: "issuer",
            subject: "subject",
            audience: "audience",
            expiration: Date.distantFuture,
            notBefore: Date.distantPast,
            issuedAt: Date(),
            jwtID: "jwtID",
            misc: ["foo": "bar"]
        )

        do {
            let encodedClaims = try JSONEncoder().encode(originalClaims)
            let decodedClaims = try JSONDecoder().decode(JWT.Claims.self, from: encodedClaims)

            XCTAssertEqual(originalClaims.issuer, decodedClaims.issuer)
            XCTAssertEqual(originalClaims.subject, decodedClaims.subject)
            XCTAssertEqual(originalClaims.audience, decodedClaims.audience)
            XCTAssertEqual(originalClaims.expiration, decodedClaims.expiration)
            XCTAssertEqual(originalClaims.notBefore, decodedClaims.notBefore)
            XCTAssertEqual(originalClaims.issuedAt, decodedClaims.issuedAt)
            XCTAssertEqual(originalClaims.jwtID, decodedClaims.jwtID)
            
            // Log and compare custom claims
            let originalMiscValue = originalClaims.miscellaneous?["foo"]?.value as? String
            let decodedMiscValue = decodedClaims.miscellaneous?["foo"]?.value as? String

            if let originalMiscValue = originalMiscValue, let decodedMiscValue = decodedMiscValue {
                XCTAssertEqual(originalMiscValue, decodedMiscValue, "Misc claims did not match.")
            } else {
                XCTFail("Custom claims could not be found or did not match. Original: \(String(describing: originalMiscValue)), Decoded: \(String(describing: decodedMiscValue))")
            }

        } catch {
            XCTFail("Encoding or decoding failed with error: \(error)")
        }
    }
}
