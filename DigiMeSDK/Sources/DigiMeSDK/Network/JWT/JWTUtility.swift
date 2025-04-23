//
//  JWTUtility.swift
//  DigiMeSDK
//
//  Created on 04/12/2019.
//  Copyright © 2019 digi.me Limited. All rights reserved.
//

import DigiMeCore
import Foundation

extension OAuthToken: JWTClaims {
}

protocol RequestClaims: JWTClaims {
}

extension RequestClaims {
    func encode() throws -> String {
		let data = try self.encoded(dateEncodingStrategy: .millisecondsSince1970)
        return data.base64URLEncodedString()
    }
}

enum JWTUtility {
	private enum Action: String {
		case auth
		case service
		case reauth
        case revoke
	}
	
	private struct PayloadRequestBasicJWT: RequestClaims {
		let clientId: String
		var nonce = JWTUtility.generateNonce()
		var timestamp = Date()
		
		enum CodingKeys: String, CodingKey {
			case clientId = "client_id"
			case nonce
			case timestamp
		}
	}
	
    // Claims to request a pre-authorization code
    private struct PayloadRequestPreauthJWT: RequestClaims {
        let accessToken: String?
        let clientId: String
        let codeChallenge: String
        var codeChallengeMethod = "S256"
        var nonce = JWTUtility.generateNonce()
        let redirectUri: String
        var responseMode = "query"
        var responseType = "code"
        var state = JWTUtility.secureRandomHexString(length: 32)
        var timestamp = Date()
		
		enum CodingKeys: String, CodingKey {
			case accessToken = "access_token"
			case clientId = "client_id"
			case codeChallenge = "code_challenge"
			case codeChallengeMethod = "code_challenge_method"
			case nonce
			case redirectUri = "redirect_uri"
			case responseMode = "response_mode"
			case responseType = "response_type"
			case state
			case timestamp
		}
    }
    
    // Claims to request a user library re-authorization
    private struct PayloadRequestUserReauthJWT: RequestClaims {
        let accessToken: String?
        let clientId: String
        let codeChallenge: String
        var codeChallengeMethod = "S256"
        var nonce = JWTUtility.generateNonce()
        let redirectUri: String
        var state = JWTUtility.secureRandomHexString(length: 32)
        var timestamp = Date()
        
        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case clientId = "client_id"
            case codeChallenge = "code_challenge"
            case codeChallengeMethod = "code_challenge_method"
            case nonce
            case redirectUri = "redirect_uri"
            case state
            case timestamp
        }
    }
    
    // Claims for pre-authorization code response
    private struct PayloadResponsePreauthJWT: JWTClaims {
        let preAuthCode: String

        enum CodingKeys: String, CodingKey {
            case preAuthCode = "preauthorization_code"
        }
    }
    
    // Claims for pre-authorization code response
    private struct PayloadResponseTokenReferenceJWT: JWTClaims {
        let referenceCode: String
        let tokenType: String
        let expiry: Date

        enum CodingKeys: String, CodingKey {
            case referenceCode = "reference_code"
            case tokenType = "token_type"
            case expiry = "expires_on"
        }
    }
    
    // Claims to request a authorization code
    private struct PayloadRequestAuthJWT: RequestClaims {
        let clientId: String
        let code: String
        let codeVerifier: String
		var grantType = "authorization_code"
        var nonce = JWTUtility.generateNonce()
        var timestamp = Date()
		
		enum CodingKeys: String, CodingKey {
			case clientId = "client_id"
			case code
			case codeVerifier = "code_verifier"
			case grantType = "grant_type"
			case nonce
			case timestamp
		}
    }
    
    // Claims to with access token.
    private struct PayloadWithAccessTokenJWT: RequestClaims {
        let accessToken: String
        let clientId: String
        var nonce = JWTUtility.generateNonce()
        var timestamp = Date()
		
		enum CodingKeys: String, CodingKey {
			case accessToken = "access_token"
			case clientId = "client_id"
			case nonce
			case timestamp
		}
    }
    
    // Claims to request OAuth token renewal
    private struct PayloadRefreshOAuthJWT: RequestClaims {
        let clientId: String
		var grantType = "refresh_token"
        var nonce = JWTUtility.generateNonce()
        let refreshToken: String
        var timestamp = Date()
		
		enum CodingKeys: String, CodingKey {
			case clientId = "client_id"
			case grantType = "grant_type"
			case nonce
			case refreshToken = "refresh_token"
			case timestamp
		}
    }
    
    // Claims to request writing data
    private struct PayloadWriteJWT: RequestClaims {
        let accessToken: String
        let clientId: String
        let iv: String
        let metadata: String
        var nonce = JWTUtility.generateNonce()
        let symmetricalKey: String
        var timestamp = Date()
		
		enum CodingKeys: String, CodingKey {
			case accessToken = "access_token"
			case clientId = "client_id"
			case iv
			case metadata
			case nonce
			case symmetricalKey = "symmetrical_key"
			case timestamp
		}
    }
	
	private struct PayloadRequestTokenReferenceJWT: RequestClaims {
		let accessToken: String
		let clientId: String
		var nonce = JWTUtility.generateNonce()
		var timestamp = Date()
		let redirectUri: String
		
		enum CodingKeys: String, CodingKey {
			case accessToken = "access_token"
			case clientId = "client_id"
			case nonce
			case timestamp
			case redirectUri = "redirect_uri"
		}
	}
	
	// Claims to request uploading data file descriptor
	private struct PayloadFileDescriptorUploadJWT: RequestClaims {
		let metadata: RawFileMetadata
	}

    /// Creates request JWT which can be used to get a pre-authentication token
    ///
    /// If a contract has already been linked to a library and both its access and refersh tokens have expired, then passing the expired access token will reauthorize access to the library
    ///
    /// If one contract has been linked to a library and another contract wants to be linked to the same library, then pass the access token for the contract which is already linked
    ///
    /// - Parameters:
    ///   - configuration: this SDK's instance configuration
    ///   - accessToken: An existing access token
    static func preAuthorizationRequestJWT(configuration: Configuration, accessToken: String?) -> String? {
        let randomBytes = Crypto.secureRandomData(length: 32)
        let codeVerifier = randomBytes.base64URLEncodedString()
        let codeChallenge = Crypto.sha256Hash(from: codeVerifier).base64URLEncodedString()
        saveCodeVerifier(codeVerifier, configuration: configuration)
        
        let claims = PayloadRequestPreauthJWT(
            accessToken: accessToken,
            clientId: configuration.clientId,
            codeChallenge: codeChallenge,
            
            // NB! this redirect schema must exist in the contract definition, otherwise preauth request will fail!
			redirectUri: configuration.redirectUri + Action.auth.rawValue
        )
        
        return createRequestJWT(claims: claims, configuration: configuration)
    }
    
    /// Creates request JWT which can be used to generate new credentials when refresh token has expired
    ///
    /// - Parameters:
    ///   - configuration: this SDK's instance configuration
    ///   - accessToken: An existing access token
    static func userReauthRequestJWT(configuration: Configuration, accessToken: String?) -> String? {
        let randomBytes = Crypto.secureRandomData(length: 32)
        let codeVerifier = randomBytes.base64URLEncodedString()
        let codeChallenge = Crypto.sha256Hash(from: codeVerifier).base64URLEncodedString()
        saveCodeVerifier(codeVerifier, configuration: configuration)
        
        let claims = PayloadRequestUserReauthJWT(
            accessToken: accessToken,
            clientId: configuration.clientId,
            codeChallenge: codeChallenge,
            redirectUri: configuration.redirectUri + Action.auth.rawValue
        )
        
        return createRequestJWT(claims: claims, configuration: configuration)
    }
	
	static func basicRequestJWT(configuration: Configuration) -> String? {
		let claims = PayloadRequestBasicJWT(clientId: configuration.clientId)
		return createRequestJWT(claims: claims, configuration: configuration)
	}
    
    /// Creates request JWT which can be used to get an authentication token
    ///
    /// - Parameters:
    ///   - authCode: OAuth authorization code
    ///   - configuration: this SDK's instance configuration
    static func authorizationRequestJWT(authCode: String, configuration: Configuration) -> String? {
        let claims = PayloadRequestAuthJWT(
            clientId: configuration.clientId,
            code: authCode,
            codeVerifier: retrieveCodeVerifier(configuration: configuration)!
        )
        
        return createRequestJWT(claims: claims, configuration: configuration)
    }
    
    /// Extracts preAuthorization code from JWT
    ///
    /// - Parameters:
    ///   - jwt: pre-authorization code wrapped in JWT
    ///   - keySet: JSON Web Key Set
    /// - Returns: The pre-authorization code if successful or an error if not
    static func preAuthCode(from jwt: String, keySet: JSONWebKeySet) -> Result<String, SDKError> {
        return Result {
            let decodedJwt = try JWT<PayloadResponsePreauthJWT>(jwtString: jwt, keySet: keySet)
            return decodedJwt.claims.preAuthCode
        }.mapError { _ in SDKError.errorDecodedingJwtPreAuthCode }
    }
    
    /// Extracts access and refresh tokens from JWT, and wraps in `OAuthToken`.
    ///
    /// - Parameters:
    ///   - jwt: JSON Web Token containing access/refresh token pair.
    ///   - keySet: JSON Web Key Set
    /// - Returns: An `OAuthToken` if successful or an error if not
    static func oAuthToken(from jwt: String, keySet: JSONWebKeySet) -> Result<OAuthToken, SDKError> {
        return Result {
            let decodedJwt = try  JWT<OAuthToken>(jwtString: jwt, keySet: keySet)
            return decodedJwt.claims
        }.mapError { _ in SDKError.errorExtractingTokensFromJwt }
    }
    
    /// Extracts reference code from JWT
    ///
    /// - Parameters:
    ///   - jwt: reference code wrapped in JWT
    ///   - keySet: JSON Web Key Set
    /// - Returns: The reference code if successful or an error if not
    static func referenceCode(from jwt: String, keySet: JSONWebKeySet) -> Result<String, SDKError> {
        return Result {
            let decodedJwt = try JWT<PayloadResponseTokenReferenceJWT>(jwtString: jwt, keySet: keySet)
            return decodedJwt.claims.referenceCode
        }.mapError { _ in SDKError.errorExtractingReferenceCodeFromJwt }
    }
    
    /// Creates request JWT with access token, client id, nonce and time stamp.
    ///
    /// - Parameters:
    ///   - accessToken: OAuth access token
    ///   - configuration: this SDK's instance configuration
    static func dataRequestJWT(accessToken: String, configuration: Configuration) -> String? {
        let claims = PayloadWithAccessTokenJWT(
            accessToken: accessToken,
			clientId: configuration.clientId
        )
        
        return createRequestJWT(claims: claims, configuration: configuration)
    }
	
	/// Creates request JWT which can be used to download file
	///
	/// - Parameters:
	///   - accessToken: OAuth access token
	///   - configuration: this SDK's instance configuration
	static func requestTokenReferenceJWT(accessToken: String, configuration: Configuration) -> String? {
		let claims = PayloadRequestTokenReferenceJWT(
			accessToken: accessToken,
			clientId: configuration.clientId,
			redirectUri: configuration.redirectUri + Action.service.rawValue
		)
		
		return createRequestJWT(claims: claims, configuration: configuration)
	}
	
    /// Creates request JWT which can be used to refresh oauth tokens
    ///
    /// - Parameters:
    ///   - refreshToken: OAuth refresh token
    ///   - configuration: this SDK's instance configuration
    static func refreshTokensRequestJWT(refreshToken: String, configuration: Configuration) -> String? {
        let claims = PayloadRefreshOAuthJWT(
            clientId: configuration.clientId,
            refreshToken: refreshToken
        )
        
        return createRequestJWT(claims: claims, configuration: configuration)
    }
    
    /// Creates request JWT which can be used to write data
    ///
    /// - Parameters:
    ///   - accessToken: OAuth refresh token
    ///   - iv: iv used to encrypt data
    ///   - metadata: metadata describing data being pushed
    ///   - symmetricKey: symmetric key used to encrypt data
    ///   - configuration: this SDK's instance configuration
    static func writeRequestJWT(accessToken: String, iv: Data, metadata: String, symmetricKey: String, configuration: Configuration) -> String? {
        let claims = PayloadWriteJWT(
            accessToken: accessToken,
            clientId: configuration.clientId,
            iv: iv.hexString,
            metadata: metadata.replacingOccurrences(of: "[\\n\\r]", with: "", options: .regularExpression, range: nil),
            symmetricalKey: symmetricKey.replacingOccurrences(of: "[\\n\\r]", with: "", options: .regularExpression, range: nil)
        )

        return createRequestJWT(claims: claims, configuration: configuration)
    }
	
	/// Creates request JWT which can be used to upload file data descriptor
	///
	/// - Parameters:
	///   - metadata: metadata describing data being uploaded
	///   - configuration: this SDK's instance configuration
	static func fileDescriptorUploadRequestJWT(metadata: RawFileMetadata, configuration: Configuration) -> String? {
		let claims = PayloadFileDescriptorUploadJWT(
			metadata: metadata
		)

		return createRequestJWT(claims: claims, configuration: configuration)
	}

    static func accountRevokeCallbackURLString(_ configuration: Configuration) -> String {
        return configuration.redirectUri + Action.revoke.rawValue
    }

    // MARK: - Utility functions
    private static func createRequestJWT<T: RequestClaims>(claims: T, configuration: Configuration) -> String? {
        let jwt = JWT(claims: claims)
        return try? jwt.sign(using: configuration.privateKeyData)
    }
    
    private static func generateNonce() -> String {
        secureRandomHexString(length: 16)
    }
    
    private static func secureRandomHexString(length: Int) -> String {
        Crypto.secureRandomBytes(length: length).hexString
    }
}

// MARK: - Utility extensions

extension JWTUtility {
    private static let codeVerifierPrefix: String = "me.digi.sdk.codeVerifier."
    
    // save code verifier for OAuth session
    private static func saveCodeVerifier(_ codeVerifier: String, configuration: Configuration) {
        let defaults = UserDefaults.standard
        defaults.set(codeVerifier, forKey: JWTUtility.codeVerifierPrefix + configuration.contractId)
    }
    
    private static func retrieveCodeVerifier(configuration: Configuration) -> String? {
        return UserDefaults.standard.object(forKey: JWTUtility.codeVerifierPrefix + configuration.contractId) as? String
    }
}

// MARK: - Provisional Cloud Support

/// `CloudJWTClaims` struct defines the structure for JWT claims used in cloud-based API authentication.
struct CloudJWTClaims: RequestClaims {
    // JWT claim "subject" typically indicates the entity this JWT represents.
    let sub: String

    // JWT claim "issuer" identifies the principal that issued the JWT.
    let iss: String

    // JWT claim "audience" identifies the recipients that the JWT is intended for.
    let aud: String

    // JWT claim "issued at" is a timestamp of when the JWT was issued.
    let iat: Int

    // JWT claim "expiration time" is a timestamp of when the JWT will expire.
    let exp: Int

    // `CodingKeys` enum specifies the keys that are used in the JWT payload.
    enum CodingKeys: String, CodingKey {
        case sub, iss, aud, iat, exp
    }

    /// Encodes the current claims into a Base64-URL encoded JSON string suitable for JWT payload.
    ///
    /// - Returns: A base64-URL encoded string representing the serialized form of the claims.
    /// - Throws: An error if encoding fails.
    func encode() throws -> String {
        let encoder = JSONEncoder()

        // Configures the encoder to represent dates as Unix timestamp seconds.
        // This is used for `iat` and `exp` claims to ensure they are encoded as integers.
        encoder.dateEncodingStrategy = .secondsSince1970

        // Attempts to encode the claims as JSON data.
        let data = try encoder.encode(self)

        // Converts the JSON data into a base64-URL encoded string, which is the format required for JWT payloads.
        return data.base64URLEncodedString()
    }
}

extension JWTUtility {
    static func createCloudJWT(configuration: Configuration) -> String? {
        let currentTime = Int(Date().timeIntervalSince1970)
        let claims = CloudJWTClaims(
            sub: configuration.appId,
            iss: configuration.contractId,
            aud: "cloud",
            iat: currentTime,
            exp: currentTime + 59  // Expires after 60 seconds
        )

        let header = JWTHeader(
            typ: "at+jwt",
            alg: "PS512",
            kid: "\(configuration.contractId)_\(configuration.appId)_0"
        )

        let jwt = JWT(header: header, claims: claims)
        let signed = try? jwt.sign(using: configuration.privateKeyData)
        return signed
    }
}
