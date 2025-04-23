//
//  SDKError.swift
//  DigiMeCore
//
//  Created on 11/06/2021.
//  Copyright © 2021 digi.me Limited. All rights reserved.
//

import Foundation

/// SDK Errors
public enum SDKError: Error {
    
    // MARK: - SDK Setup Errors
    
    /// URL Scheme not set in Info.plist
    /// This is an implementation error and can be resolved by setting the CFBundleURLSchemes in Info.plist to include "digime-ca-YOUR_APP_ID" using your actual app identifier in place of YOUR_APP_ID.
    case noUrlScheme
    
    /// App identifier is using placeholder value "YOUR_APP_ID"
    /// This is an implementation error and can be resolved by using your actual app identifier in place of YOUR_APP_ID.
    case invalidAppId
    
    /// The private or public key is invalid
    /// This is an implementation error and can be resolved by ensuring that you are using keys beginning with "-----BEGIN RSA {PRIVATE/PUBLIC} KEY----" as appropriate.
    case invalidPrivateOrPublicKey
    
    // MARK: - Runtime Errors
    
    /// The contract needs authorizing.
    /// This is either caused by the contract not having been authorized or the contract's credentials expired requiring user to reauthorize
    case authorizationRequired
    
    /// The session used to retrieve data is invalid. To refresh the session, please please request another data query.
    case invalidSession
    
    /// Server has returned data which cannot be read
    case invalidData
    
    /// File list time out reached as there have been no changes.
    case fileListPollingTimeout

    /// The contract to link to has not been authorized
    case linkedContractNotAuthorized
    
    /// User cancelled authorization
    case authorizationCancelled
    
    /// An error occurred when adding a service
    case addingServiceFailed
    
    /// Authorization failed with the specified code
    case authorizationFailed(code: String)
    
    /// An error occurred when communicating with digi.me server. Contains underlying error - typically an instance of URLError
    case urlRequestFailed(error: Error)
    
    /// An unsuccessful HTTP response was returned from digi.me server
    case httpResponseError(statusCode: Int, apiError: APIError?)
    
    /// An error occurred while encrypting write request
    case writeRequestFailure
    
    /// Unable to encode the metadata associated with a write request
    case invalidWriteMetadata
    
    /// This SDK version is no longer supported - please update to latest version
    case invalidSdkVersion
    
    /// Requested read options are out of bounds with respect to the contract's scope
    case scopeOutOfBounds
    
    /// Attempting to read with a write contract or write with a read contract
    case incorrectContractType
    
    /// Only one call to `readAllFiles` can be in progress at any time for each `DigiMe` instance
    case alreadyReadingAllFiles

    /// Sync has been in pending state for too long
    case syncPendingTimeout

    /// Sync has exceeded the maximum duration
    case syncTimeout

	/// Error reading accounts json
	case readAccountsError
	
	/// Attempting to extract preAuthorization code from JWT
	case errorDecodedingJwtPreAuthCode
    
	/// Attempting to extract access and refresh tokens from JWT
	case errorExtractingTokensFromJwt
	
	/// Extracts reference code from JWT
	case errorExtractingReferenceCodeFromJwt
	
	/// Error parsing headers and metadata in the response
	case errorParsingHeadersMetadataInTheResponse
	
	/// Error making request when parsing response
	case errorMakingRequestWhenParsingResponse
	
	/// Error decrypting response
	case errorDecryptingResponse
    
	/// Error parsing server response. Result is unexpected.
	case unexpectedErrorWhenParsingConsentResponse
	
	/// File Download operation error
	case fileDownloadOperationError(error: Error)
	
	/// Error creating request JWT to trigger data
	case errorCreatingRequestJwtToTriggerData
	
	/// Api client making request received no response
	case errorMakingRequest
	
	/// Api client making request, received no response
	case errorMakingRequestNoResponse

	/// Invalid pre-authorization request JWT
	case invalidPreAuthorizationRequestJwt
	
	/// Invalid authorization request JWT
	case invalidAuthorizationRequestJwt
	
	/// Invalid account reference request JWT
	case invalidAccountReferenceRequestJwt
	
	/// Invalid refresh tokens request JWT
	case invalidRefreshTokensRequestJwt

	/// Invalid reference token request JWT
	case invalidReferenceTokenRequestJwt
	
    /// Invalid reauthorize user token request JWT
    case invalidReauthorizeUserTokenRequestJwt
    
	/// Invalid delete user token request JWT
	case invalidDeleteUserTokenRequestJwt
	
    /// Invalid delete account token request JWT
    case invalidDeleteAccountTokenRequestJwt

	/// Error creating request JWT to download file
	case errorCreatingDataRequestJwt
	
    /// Error creating request JWT to export report
    case errorCreatingRequestJwtToExportReport
    
    /// Invalid  basic request JWT
    case invalidBasicRequestJwt

    /// An unsuccessful HTTP response was returned from digi.me server
    case storageResponseError(statusCode: Int?, errorMessage: String?)

    /// An unexpected error has occurred - please contact support
    case other
    
    // MARK: - Apple Health
    
    /// Returns if HealthKit is not supported on the device.
    /// HealthKit is not supported on all iOS devices.  Using HKHealthStore APIs on devices which are not supported will result in errors with the HKErrorHealthDataUnavailable code.
    case healthDataIsNotAvailable
    
    /// Returns YES if the Health Records feature is available.
    /// The Health Records feature is not available in all regions but may be present in unsupported regions if accounts have already been configured. This can change as accounts are modified during device restore or synchronization.
    case healthDataNotSupportsHealthRecords
    
    /// Health data failure with a specific message
    case healthDataError(message: String)
    
    /// Authorization failed with the specified error
    case healthDataErrorError(error: Error)
    
    /// Invalid or missing X509 contract data
    case certificateParserInvalidData
    
    /// An error occured when parsing certificate
    case certificateParserError(error: Error)
    
    /// Error parsing time range in data request
    case certificateVerifyTimeRangeError
    
    /// Certificate type is not supported
    case certificateTypeIsNotSupported
    
    /// An error occured while encoding certificate data
    case certificateEncodingDataError
    
    /// Certificate format is not supported
    case certificateFormatIsNotSupported
    
    /// Health Data Store. Error fetch statistics
    case healthDataFetchStatistics(error: Error)
    
    /// Health Data Store. Unable to create quantity type
    case healthDataUnableToCreateQuantityType
	
	/// Health Data Store. Unable to upload mixpanel event
	case healthDataUnableToUploadLogEvent
	
	/// Health Data Store.  Not available
	case notAvailable(message: String)
	
	/// Health Data Store. Unknown object type for query.
	case unknown(message: String)
	
	/// Health Data Store. Invalid type.
	case invalidType(message: String)
	
	/// Health Data Store. Invalid identifier.
	case invalidIdentifier(message: String)
	
	/// Health Data Store. Invalid value.
	case invalidValue(message: String)
	
	/// Health Data Store. Parsing failed
	case parsingFailed(message: String)
	
	/// Health Data Store. Bad encoding.
	case badEncoding(message: String)
}

// MARK: - CustomStringConvertible
extension SDKError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidData:
            return "Server has returned data which cannot be read."

        case .noUrlScheme:
            return "CFBundleURLSchemes in Info.plist must include 'digime-ca-YOUR_APP_ID' using your actual app identifier in place of 'YOUR_APP_ID'."
        
        case .invalidAppId:
            return "The placeholder `YOUR_APP_ID` needs to be replaced with your actual app identifier."
        
        case .authorizationRequired:
            return "This contract either needs to be authorized for the first time or reauthorized due to expired credentials"
        
        case .invalidSession:
            return "The session used to retrieve data is invalid. To refresh the session, please request another data query."
            
        case .fileListPollingTimeout:
            return "Retrieving files has timed out"
        
        case .invalidPrivateOrPublicKey:
            return "The private or public key is invalid. Please unsure the keys used begin with either:\n\t`-----BEGIN RSA PRIVATE KEY-----` or\n\t`-----BEGIN RSA PUBLIC KEY-----`"
        
        case .linkedContractNotAuthorized:
            return "The contract to link to has not been authorized."
        
        case .authorizationCancelled:
            return "User cancelled authorization."
        
        case .addingServiceFailed:
            return "An error occurred when adding a service."
        
        case .authorizationFailed(let code):
            return "Authorization failed with code \(code)."
        
        case .urlRequestFailed(let error):
            return "A general communication error occurred: \(error)"
        
        case let .httpResponseError(statusCode, apiError):
            var message = "An unsuccessful HTTP response was returned from digi.me server. Status code: \(statusCode)."
            if let apiError = apiError {
                message += " Error code: \(apiError.code). Error message: `\(apiError.message)`."
            }
            
            return message
        
        case .writeRequestFailure:
            return "An error occurred while encrypting write request."
        
        case .invalidWriteMetadata:
            return "Unable to encode the metadata associated with a write request."
        
        case .invalidSdkVersion:
            return "This SDK version is no longer supported - please update to latest version."
        
        case .scopeOutOfBounds:
            return "Requested read options are out of bounds with respect to the contract's scope."
        
        case .incorrectContractType:
            return "Attempting to read with a write contract or write with a read contract."
            
        case .alreadyReadingAllFiles:
            return "Only one call to `readAllFiles` can be in progress at any time for each `DigiMe` instance. Try cancelling existing call if a new call is required."
            
        case .syncPendingTimeout:
            return "Sync has been in pending state for too long"

        case .syncTimeout:
            return "Sync has exceeded the maximum allowed duration. Please try again later."

		case .readAccountsError:
			return "Error reading accounts json"
				
		case .errorDecodedingJwtPreAuthCode:
			return "Attempting to extract preAuthorization code from JWT"
				
		case .errorExtractingTokensFromJwt:
			return "Attempting to extract access and refresh tokens from JWT"
				
		case .errorExtractingReferenceCodeFromJwt:
			return "Error attempting to extract reference code from JWT"
				
		case .errorParsingHeadersMetadataInTheResponse:
			return "Error parsing headers and metadata in the response"
				
		case .errorMakingRequestWhenParsingResponse:
			return "Error making request when parsing response"
			
		case .errorDecryptingResponse:
			return "Error decrypting response"
            
		case .unexpectedErrorWhenParsingConsentResponse:
			return "Error parsing server response. Result is unexpected."
		
		case .fileDownloadOperationError(let error):
			return "File Download operation error: \(error.localizedDescription)"
		
		case .errorCreatingRequestJwtToTriggerData:
			return "Error creating request JWT to trigger data"
				
		case .errorMakingRequest:
			return "Api client making request received no response"
				
		case .errorMakingRequestNoResponse:
			return "Api client making request, received no response"
				
		case .invalidPreAuthorizationRequestJwt:
			return "Invalid pre-authorization request JWT"
		
		case .invalidAccountReferenceRequestJwt:
			return "Invalid account reference request JWT"
			
		case .invalidRefreshTokensRequestJwt:
			return "Invalid refresh tokens request JWT"
			
		case .invalidReferenceTokenRequestJwt:
			return "Invalid reference token request JWT"
		
        case .invalidReauthorizeUserTokenRequestJwt:
            return "Invalid reauthorize user token request JWT"
            
		case .invalidAuthorizationRequestJwt:
			return "Invalid authorization request JWT"
		
		case .invalidDeleteUserTokenRequestJwt:
			return "Invalid delete user token request JWT"
			
        case .invalidDeleteAccountTokenRequestJwt:
            return "Invalid delete account token request JWT"

		case .errorCreatingDataRequestJwt:
			return "Error creating data request JWT"
            
        case .errorCreatingRequestJwtToExportReport:
            return "Error creating JWT to export report"
		
        case .invalidBasicRequestJwt:
            return "Error creating basic request JWT"

        case let .storageResponseError(statusCode, errorMessage):
            guard let statusCode = statusCode, let errorMessage = errorMessage else {
                return "An unsuccessful HTTP response was returned from cloud.digi.me server."
            }
            
            return "An unsuccessful HTTP response was returned from cloud.digi.me server. Status code: \(statusCode). Error message: `\(errorMessage)`"

        case .other:
            return "An unexpected error has occurred - please contact digi.me support."
	
		// MARK: - Apple Health
			
		case .healthDataIsNotAvailable:
			return "HealthKit is not supported on the device."
			
		case .healthDataNotSupportsHealthRecords:
			return "The Health Records feature is not available."
			
		case .healthDataError(let message):
			return "Health Data Failure: \(message)"
			
		case .healthDataErrorError(let error):
			return "Health Data. Authorization failed with error: \(error)"
			
		case .certificateParserInvalidData:
			return "Invalid or missing X509 contract data"
			
		case .certificateParserError(let error):
			return "Error parsing X509 certificate: \(error)"
			
		case .certificateVerifyTimeRangeError:
			return "Error parsing time range in data request"
			
		case .certificateTypeIsNotSupported:
			return "Certificate type is not supported"
			
		case .certificateEncodingDataError:
			return "An error occured while encoding certificate data"
			
		case .certificateFormatIsNotSupported:
			return "Certificate format is not supported"
			
		case .healthDataFetchStatistics(let error):
			return "Health Data Store. Error fetch statistics: \(error)"
			
		case .healthDataUnableToCreateQuantityType:
			return "Health Data Store. Unable to create quantity type"
			
		case .healthDataUnableToUploadLogEvent:
			return "Health Data Store. Failed to upload mixpanel event"
		
		case .notAvailable(let message):
			return "Health Data Store. \(message)"
			
		case .unknown(let message):
			return message

		case .invalidType(let message):
			return "Health Data Store. Invalid type. \(message)"
		
		case .invalidIdentifier(let message):
			return "Health Data Store. Invalid identifier. \(message)"
		
		case .invalidValue(let message):
			return "Health Data Store. Invalid value. \(message)"
		
		case .parsingFailed(let message):
			return "Health Data Store. Parsing failed. \(message)"
		
		case .badEncoding(let message):
			return "Health Data Store. Bad encoding. \(message)"
		}
    }
}
