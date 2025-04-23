//
//  DigiMe.swift
//  DigiMeSDK
//
//  Created on 08/06/2021.
//  Copyright © 2021 digi.me Limited. All rights reserved.
//

import DigiMeCore
import Foundation

/// The entry point to the SDK
public final class DigiMe {
    
    public var isDownloadingFiles: Bool {
        return self.downloadService.isDownloadingFiles
    }

    public var isDownloadingStorageFiles: Bool {
        return self.downloadStorageService.isDownloadingFiles
    }

    private let configuration: Configuration
	private let authService: OAuthService
    private let consentManager: ConsentManager
    private let sessionCache: SessionCache
	private let contractsCache: ContractsCache
    private let apiClient: APIClient
    private let storageClient: StorageClient
    private let dataDecryptor: DataDecryptor
    private let certificateParser: CertificateParser
    
    // Apple Health
	private var healthSerivce: HealthKitServiceProtocol?
    private var healthDataFilesSerivce: HealthKitFilesDataServiceProtocol?
    private var healthAccount: SourceAccount?
    private var healthAccountData: SourceAccountData?
    
    private lazy var downloadService: FileDownloadService = {
        FileDownloadService(apiClient: apiClient, dataDecryptor: dataDecryptor)
    }()
    
    private lazy var uploadService: FileUploadService = {
        FileUploadService(apiClient: apiClient, configuration: configuration)
    }()

    private lazy var downloadStorageService: StorageDownloadService = {
        StorageDownloadService(storageClient: storageClient, dataDecryptor: dataDecryptor)
    }()

    private lazy var uploadStorageService: StorageUploadService = {
        StorageUploadService(storageClient: storageClient, configuration: configuration)
    }()

    @Atomic private var allFilesReader: AllFilesReader?
    
    private var session: Session? {
        get {
            sessionCache.session(for: configuration.contractId)
        }
        set {
            sessionCache.setSession(newValue, for: configuration.contractId)
        }
    }
    
    /// The log levels for all `DigiMe` instances which will be included in logs.
    /// Defaults to `[.info, .warning, .error, .critical]`
    public class var logLevels: [LogLevel] {
        get {
            Logger.logLevels
        }
        set {
            Logger.logLevels = newValue
        }
    }
    
    /// Sets the custom log handler for all `DigiMe` instances to allow logging to a different system.
    /// DigiMeSDK uses `NSLog` by default.
    /// - Parameter handler: The log handler block
    public class func setLogHandler(_ handler: @escaping LogHandler) {
        Logger.setLogHandler(handler)
    }
    
    /// Initialises a new instance of SDK.
    /// A new instance should be created for each contract the app uses
    /// - Parameter configuration: The configuration which defines this instance
    public init(configuration: Configuration) {
        self.configuration = configuration
		self.apiClient = APIClient(with: configuration.baseUrl)
        self.storageClient = StorageClient(with: configuration.cloudBaseUrl)
        self.authService = OAuthService(configuration: configuration, apiClient: apiClient)
        self.consentManager = ConsentManager(configuration: configuration)
        self.sessionCache = SessionCache()
		self.contractsCache = ContractsCache()
        self.dataDecryptor = DataDecryptor(configuration: configuration)
        self.certificateParser = CertificateParser()

        if let healthSerivceType = NSClassFromString("DigiMeHealthKit.HealthKitService") as? HealthKitServiceProtocol.Type {
            let healthSerivce = healthSerivceType.init()
            self.healthSerivce = healthSerivce
            if
                let healthAccountType = NSClassFromString("DigiMeHealthKit.HealthKitAccountDataProvider") as? HealthKitAccountDataProviderProtocol.Type,
                let healthDataFilesSerivceType = NSClassFromString("DigiMeHealthKit.HealthKitFilesDataService") as? HealthKitFilesDataServiceProtocol.Type {
                
                let account = healthAccountType.init()
                self.healthAccount = account.sourceAccount
                self.healthAccountData = account.sourceAccountData
                self.healthDataFilesSerivce = healthDataFilesSerivceType.init(account: account.sourceAccount, healthKitService: healthSerivce)
            }
        }
        
        setupLogger()
    }
    
    /// Authorizes the contract configured with this digi.me instance to access to a library.
    ///
    /// Requires `CallbackService.shared().handleCallback(url:)` to be called from appropriate in `AppDelegate` or `SceneDelegate`place so that authorization can complete.
    ///
    /// If the user has not already authorized, will present a view controller in which user consents.
    /// If user has already authorized, refreshes the authorization, if necessary (which may require user consent again).
    ///
    /// To authorize this contract to access the same library that another contract has been authorized to access, specify the contract to link to's credentials. This is useful when a read contract needs to access the same library that a write contract has written deta to.
    ///
    /// Additionally for read contracts:
    /// - Upon first authorization, can optionally specify a service from which user can log in to and retrieve data.
    /// - Creates of refreshes a session during which data can be read from library.
    ///
    /// - Parameters:
    ///   - credentials: The existing credentials for the contract to authorize. If nil, will create credentials on success
    ///   - serviceId: Identifier of initial service to add. Only valid for first authorization of read contracts where user has not previously granted consent. Ignored for all subsequent calls.
    ///   - sampleDataSetId: Sample Dataset ID to use for sample data onboarding.
    ///   - sampleDataAutoOnboard: Skip consent swipe screen for sample data onboarding.
    ///   - includeSampleDataOnlySources: Set this flag to `true` if you are onboarding a service that provides only Sample Data.
    ///   - readOptions: Options to filter which data is read from sources for this session. Only used for read contracts.
    ///   - linkToContractWithCredentials: When specified, connects to same library as another contract.  Does nothing if user has already authorized this contract.
    ///   - resultQueue: The dispatch queue which the completion block will be called on. Defaults to main dispatch queue.
    ///   - completion: Block called upon authorization completion with new or refreshed credentials, or any errors encountered.
    ///   - storageId: The unique identifier for the cloud storage instance. This ID is typically obtained after creating a cloud instance through the SDK or via direct integration.
    public func authorize(credentials: Credentials? = nil, serviceId: Int? = nil, sampleDataSetId: String? = nil, sampleDataAutoOnboard: Bool? = nil, includeSampleDataOnlySources: Bool? = nil, readOptions: ReadOptions? = nil, linkToContractWithCredentials linkCredentials: Credentials? = nil, storageId: String? = nil, resultQueue: DispatchQueue = .main, completion: @escaping (Result<Credentials, SDKError>) -> Void) {
        if let validationError = validateClient() {
            resultQueue.async {
                completion(.failure(validationError))
            }
            return
        }
		
        validateOrRefreshCredentials(credentials) { result in
            switch result {
            case .success(let refreshedCredentials):
                resultQueue.async {
                    completion(.success(refreshedCredentials))
                }
                
            case .failure(SDKError.authorizationRequired):
                guard let storageId = storageId else {
                    self.beginAuth(serviceId: serviceId, sampleDataSetId: sampleDataSetId, sampleDataAutoOnboard: sampleDataAutoOnboard, includeSampleDataOnlySources: includeSampleDataOnlySources, readOptions: readOptions, linkToContractWithCredentials: linkCredentials) { authResult in
                        resultQueue.async {
                            completion(authResult)
                        }
                    }
                    return
                }

                self.authService.requestStorageReference(cloudId: storageId) { refStorageResult in
                    switch refStorageResult {
                    case .success(let accountRef):
                        self.beginAuth(serviceId: serviceId, sampleDataSetId: sampleDataSetId, sampleDataAutoOnboard: sampleDataAutoOnboard, readOptions: readOptions, linkToContractWithCredentials: linkCredentials, storageRef: accountRef.id) { authResult in
                        resultQueue.async {
                            completion(authResult)
                        }
                    }
                    case .failure(let error):
                        resultQueue.async {
                            completion(.failure(error))
                        }
                    }
                }

            case .failure(let error):
                resultQueue.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// In cases where access to a service's data is revoked and you receive an error message of `511 Service Authorization Required`,
    /// you can initiate the reauthentication process by requesting the re-authentication URL and directing the user to it.
    /// - Parameters:
    ///   - accountId: Service account entity identifier.
    ///   - credentials: The existing credentials for the contract.
    ///   - locale: Preferred locale for the authorization client. If the provided locale is not supported,
    ///     the language will fall back to the browser's locale. If the browser's locale is not supported,
    ///     it will fall back to the default locale (en).
    ///   - resultQueue: The dispatch queue on which the completion block will be called. Defaults to main dispatch queue.
    ///   - completion: Block called upon completion with new or refreshed credentials, or any errors encountered.
    public func reauthorizeAccount(accountId: String, credentials: Credentials, locale: String? = nil, resultQueue: DispatchQueue = .main, completion: @escaping (Credentials, Result<Void, SDKError>) -> Void) {
        validateOrRefreshCredentials(credentials) { credResult in
            switch credResult {
            case .success(let refreshedCredentials):
                self.authService.requestReferenceToken(oauthToken: refreshedCredentials.token) { refTokenResult in
                    switch refTokenResult {
                    case .success(let response):
                        self.session = response.session
                        self.authService.requestAccountReference(accountId: accountId) { refAccountResult in
                            switch refAccountResult {
                            case .success(let accountRef):
                                self.consentManager.reauthService(accountRef: accountRef.id, token: response.token, locale: locale) { result in
                                    resultQueue.async {
                                        switch result {
                                        case .success:
                                            completion(refreshedCredentials, .success(()))
                                        case .failure(let error):
                                            completion(refreshedCredentials, .failure(error))
                                        }
                                    }
                                }
                                
                            case .failure(let error):
                                resultQueue.async {
                                    completion(refreshedCredentials, .failure(error))
                                }
                            }
                        }
                        
                    case .failure(let error):
                        resultQueue.async {
                            completion(refreshedCredentials, .failure(error))
                        }
                    }
                }
                
            case .failure(let error):
                resultQueue.async {
                    completion(credentials, .failure(error))
                }
            }
        }
    }
	
    /// This is called when user receives `InvalidToken error (401 - The token (refresh_token) is invalid)`. We can use this method to get new AT/RT pair.
    /// - Parameters:
    ///   - credentials: The existing credentials for the contract.
    ///   - locale: Preferred locale for the authorization client. If the provided locale is not supported,
    ///     the language will fall back to the browser's locale. If the browser's locale is not supported,
    ///     it will fall back to the default locale (en).
    ///   - resultQueue: The dispatch queue which the completion block will be called on. Defaults to main dispatch queue.
    ///   - completion: Block called upon completion with new or refreshed credentials, or any errors encountered.
    public func reauthorize(credentials: Credentials, locale: String? = nil, resultQueue: DispatchQueue = .main, completion: @escaping (Result<Credentials, SDKError>) -> Void) {
        self.authService.reauthoriseUser(oauthToken: credentials.token) { reauthUserResult in
            switch reauthUserResult {
            case .success(let response):
                self.session = response.session
                self.consentManager.reauthUser(token: response.token, locale: locale) { result in
                    resultQueue.async {
                        switch result {
                        case .success:
                            completion(.success((credentials)))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    }
                }

            case .failure(let error):
                resultQueue.async {
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Authorizes the contract to support the storing of user entered data in a digime library with store, edit and delete functionality.
    /// - Parameters:
    ///   - credentials: The existing credentials for the contract.
    ///   - resultQueue: The dispatch queue which the completion block will be called on. Defaults to main dispatch queue.
    ///   - completion: Block called upon completion with new or refreshed credentials, or any errors encountered.
    public func authorizeServiceToPushData(credentials: Credentials? = nil, resultQueue: DispatchQueue = .main, completion: @escaping (Result<Credentials, SDKError>) -> Void) {
        
        if let validationError = validateClient() {
            resultQueue.async {
                completion(.failure(validationError))
            }
            return
        }
        
        validateOrRefreshCredentials(credentials) { result in
            switch result {
            case .success, .failure(SDKError.authorizationRequired):
                self.beginAuth(serviceId: nil, readOptions: nil, linkToContractWithCredentials: nil, onlyPushServices: true) { authResult in
                    resultQueue.async {
                        completion(authResult)
                    }
                }
                
            case .failure(let error):
                resultQueue.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Once a user has granted consent, adds an additional service. Also initiates synchronization of data from this service to user's library.
    ///
    /// - Parameters:
    ///   - identifier: Identifier of service to add.
    ///   - sampleDataSetId: Sample Dataset ID to use for sample data onboarding.
    ///   - sampleDataAutoOnboard: Skip consent swipe screen for sample data onboarding.
    ///   - includeSampleDataOnlySources: Set this flag to `true` if you are onboarding a service that provides only Sample Data.
    ///   - credentials: The existing credentials for the contract.
    ///   - resultQueue: The dispatch queue which the completion block will be called on. Defaults to main dispatch queue.
    ///   - completion: Block called upon completion with new or refreshed credentials, or any errors encountered
    public func addService(identifier: Int, sampleDataSetId: String? = nil, sampleDataAutoOnboard: Bool? = nil, includeSampleDataOnlySources: Bool? = nil, credentials: Credentials, resultQueue: DispatchQueue = .main, completion: @escaping (Credentials, Result<Void, SDKError>) -> Void) {
        validateOrRefreshCredentials(credentials) { result in
            switch result {
            case .success(let refreshedCredentials):
            self.authService.requestReferenceToken(oauthToken: refreshedCredentials.token) { result in
                switch result {
                case .success(let response):
                    self.session = response.session
                    self.consentManager.addService(identifier: identifier, token: response.token, sampleDataSetId: sampleDataSetId, sampleDataAutoOnboard: sampleDataAutoOnboard, includeSampleDataOnlySources: includeSampleDataOnlySources) { result in
                        switch result {
                        case .success:
                            resultQueue.async {
                                completion(refreshedCredentials, .success(()))
                            }
                        case .failure(let error):
                            resultQueue.async {
                                completion(refreshedCredentials, .failure(error))
                            }
                        }
                    }
                
                case .failure(let error):
                    resultQueue.async {
                        completion(refreshedCredentials, .failure(error))
                    }
                }
            }
                
            case .failure(let error):
                resultQueue.async {
                    completion(credentials, .failure(error))
                }
            }
        }
    }
    
    /// Reads the service data source accounts user has added to library related to the configured contract.
    ///
    /// Requires a valid session to have been created, either implicitly by adding a new service, or explicitly by calling `requestDataQuery(credentials:readOptions:resultQueue:completion)`.
    ///
    /// Note: If this is called on either a write-only contract or a contract which reads non-service data, this will return an error.
    ///
    /// - Parameters:
	///   - credentials: The existing credentials for the contract.
    ///   - resultQueue: The dispatch queue which the completion block will be called on. Defaults to main dispatch queue.
    ///   - completion: Block called upon completion containing either relevant account info, if successful, or an error
    public func readAccounts(credentials: Credentials, resultQueue: DispatchQueue = .main, completion: @escaping (Credentials, Result<[SourceAccountData], SDKError>) -> Void) {
        guard
            let session = session,
            session.isValid else {
            return completion(credentials, .failure(.invalidSession))
        }
        
        validateOrRefreshCredentials(credentials) { result in
            switch result {
            case .success(let refreshedCredentials):
                self.readAccounts(credentials: refreshedCredentials) { result in
                    resultQueue.async {
                        completion(refreshedCredentials, result)
                    }
                }
            case .failure(let error):
                resultQueue.async {
                    completion(credentials, .failure(error))
                }
            }
        }
    }
    
    /// Fetches content for all the files limited by read options.
    ///
    /// An attempt is made to fetch each requested file and the result of the attempt is passed back via the download handler.
    /// As download requests are asynchronous, the download handler may be called concurrently, so the handler implementation should allow for this.
    ///
    /// If this function is called while files are being read, an error denoting this will be immediately
    /// returned in the completion block of this subsequent call and will not affect any current calls.
    ///
    /// For reading data written by another contract, it may be necessary for force a new session by calling `requestDataQuery(credentials:readOptions:resultQueue:completion)` first (and waiting for completion).
    ///
    /// For service-based data sources, will also attempt to retrieve any new data directly from the services, in which case this completion handler will not be called until this synchronization has finished.
    ///
    /// Alternatively, caller can manage reading files themselves by using the calls:
    /// `requestDataQuery()`, `readFileList()` and `readFile()`
    ///
    /// - Parameters:
    ///   - credentials: The existing credentials for the contract.
    ///   - readOptions: Options to filter which data is read from sources for this session. Only used for read contracts.
    ///   - resultQueue: The dispatch queue which the download handler and completion blocks will be called on. Defaults to main dispatch queue.
    ///   - downloadHandler: Handler called after every file fetch attempt finishes. Either contains the file or an error if fetch failed
    ///   - completion: Block called when fetching all files has completed. Contains final list of files (along with new or refreshed credentials) or an error if reading file list failed
    public func readAllFiles(credentials: Credentials, readOptions: ReadOptions?, resultQueue: DispatchQueue = .main, downloadHandler: @escaping (Result<File, SDKError>) -> Void, completion: @escaping (Credentials, Result<FileList, SDKError>) -> Void) {
        guard allFilesReader == nil else {
            resultQueue.async {
                completion(credentials, .failure(SDKError.alreadyReadingAllFiles))
            }
            return
        }
        
        allFilesReader = AllFilesReader(apiClient: self.apiClient,
                                        credentials: credentials,
                                        certificateParser: self.certificateParser,
                                        contractsCache: self.contractsCache,
                                        configuration: self.configuration,
                                        healthService: self.healthSerivce,
                                        healthFilesDataService: self.healthDataFilesSerivce,
                                        readOptions: readOptions)
        
        allFilesReader?.readAllFiles(downloadHandler: { result in
            resultQueue.async {
                downloadHandler(result)
            }
        }, completion: { result in
            if case .failure(.invalidSession) = result {
                self.requestDataQuery(credentials: credentials, readOptions: readOptions, resultQueue: DispatchQueue.global()) { refreshedCredentials, result in
                    switch result {
                    case .success:
                        self.allFilesReader?.readAllFiles(downloadHandler: { result in
                            resultQueue.async {
                                downloadHandler(result)
                            }
                        }, completion: { result in
                            self.allFilesReader = nil
                            resultQueue.async {
                                completion(refreshedCredentials, result)
                            }
                        })
                        
                    case .failure(let error):
                        self.allFilesReader = nil
                        resultQueue.async {
                            completion(refreshedCredentials, .failure(error))
                        }
                    }
                }
                
                return
            }
            
            self.allFilesReader = nil
            resultQueue.async {
                completion(credentials, result)
            }
        })
    }
    
    /// Creates a session during which files can be read. This session is typically valid for 15 minutes.
    /// Once it has expired, a new session will be required to continue reading data.
    ///
    /// For service-based data sources, will also attempt to retrieve any new data directly from the services.
    ///
    /// - Parameters:
    ///   - credentials: The existing credentials for the contract.
    ///   - readOptions: Options to filter which data is read from sources for this session. Only used for read contracts.
    ///   - resultQueue: The dispatch queue which the download handler and completion blocks will be called on. Defaults to main dispatch queue.
    ///   - completion: Block called upon completion with new or refreshed credentials, or any errors encountered.
    public func requestDataQuery(credentials: Credentials, readOptions: ReadOptions?, resultQueue: DispatchQueue = .main, completion: @escaping (Credentials, Result<Void, SDKError>) -> Void) {
        validateOrRefreshCredentials(credentials) { result in
            switch result {
            case .success(let refreshedCredentials):
                self.triggerSourceSync(credentials: refreshedCredentials, readOptions: readOptions, completion: completion)
                
            case .failure(let error):
                resultQueue.async {
                    completion(credentials, .failure(error))
                }
            }
        }
    }
    
    /// Retrieves a list of files contained within the user's library.
    ///
    /// Requires a valid session to have been created, either implicitly by adding a new service, or explicitly by calling `requestDataQuery(credentials:readOptions:resultQueue:completion)`.
    ///
    /// For service-based sources, it can take a while for new data to be added to user's library (following a `requestDataQuery` call).
    /// Therefore caller should poll this call while data is being added to the library in case new files become available.
    /// Synchronization is complete when `fileList.status.state.isRunning` becomes `false`.
    ///
    /// - Parameters:
	///   - credentials: The existing credentials for the contract.
    ///   - resultQueue: The dispatch queue which the download handler and completion blocks will be called on. Defaults to main dispatch queue.
    ///   - completion: Block called upon completion with the list of files, or any errors encountered.
    public func readFileList(credentials: Credentials, resultQueue: DispatchQueue = .main, completion: @escaping (Credentials, Result<FileList, SDKError>) -> Void) {
        guard
            let session = session,
            session.isValid else {
            return completion(credentials, .failure(.invalidSession))
        }
        
        validateOrRefreshCredentials(credentials) { result in
            switch result {
            case .success(let refreshedCredentials):
                guard let jwt = JWTUtility.dataRequestJWT(accessToken: refreshedCredentials.token.accessToken.value, configuration: self.configuration) else {
                    return completion(refreshedCredentials, .failure(.errorCreatingDataRequestJwt))
                }
                
                let route = FileListRoute(jwt: jwt, sessionKey: session.key)
                self.apiClient.makeRequest(route) { result in
                    resultQueue.async {
                        completion(refreshedCredentials, result)
                    }
                }
            case .failure(let error):
                resultQueue.async {
                    completion(credentials, .failure(error))
                }
            }
        }
    }

    /// Retrieves the content of a specified file.
    ///
    /// Requires a valid session to have been created, either implicitly by adding a new service, or explicitly by calling `requestDataQuery(credentials:readOptions:resultQueue:completion)`.
    ///
    /// - Parameters:
    ///  - fileId: The file's identifier.
    ///  - credentials: The existing credentials for the contract.
    ///  - resultQueue: The dispatch queue which the download handler and completion blocks will be called on. Defaults to main dispatch queue.
    ///  - completion: Block called upon completion with file, or any errors encountered.
    public func readFile(fileId: String, credentials: Credentials, resultQueue: DispatchQueue = .main, completion: @escaping (Credentials, Result<File, SDKError>) -> Void) {
        guard
            let session = session,
            session.isValid else {
            return completion(credentials, .failure(.invalidSession))
        }
        
        validateOrRefreshCredentials(credentials) { result in
            switch result {
            case .success(let refreshedCredentials):
                self.downloadService.downloadFile(fileId: fileId, sessionKey: session.key, credentials: refreshedCredentials, configuration: self.configuration) { result in
                    resultQueue.async {
                        completion(refreshedCredentials, result)
                    }
                }
            case .failure(let error):
                resultQueue.async {
                    completion(credentials, .failure(error))
                }
            }
        }
    }
	
    /// Retrieves sample data sets for a specific service by its identifier.
    ///
    /// This function facilitates the integration process by providing sample data sets that represent what actual data from the service would look like. 
    /// It allows developers to test and demonstrate their application's functionality without the need to connect to real service accounts such as Facebook or Twitter.
    /// This can be particularly useful for demonstrations, testing, or when real account access is not available or not desired.
    ///
    /// The function asynchronously fetches the data and returns a dictionary containing sample data set IDs as keys and `SampleDataset` objects as values. 
    /// The `SampleDataset` objects include placeholders for properties like descriptions, names, and any other relevant information to the service.
    ///
    /// - Parameters:
    ///   - serviceId: A string identifier for the service for which to retrieve sample data sets. This ID should correspond to one of the services known to the SDK.
    ///   - resultQueue: The `DispatchQueue` on which the completion handler is dispatched. By default, this parameter is set to the main queue.
    ///   - completion: A closure that is called upon completion of the request. It provides a `Result` type that contains either a dictionary of sample data sets on success or an `SDKError` on failure.
    public func fetchDemoDataSetsInfoForService(serviceId: String, resultQueue: DispatchQueue = .main, completion: @escaping (Result<[String: SampleDataset], SDKError>) -> Void) {
        guard let jwt = JWTUtility.basicRequestJWT(configuration: configuration) else {
            Logger.critical("Invalid sample data request JWT")
            completion(.failure(SDKError.invalidAccountReferenceRequestJwt))
            return
        }
        
        let route = ReadSampleDataSetsRoute(jwt: jwt, serviceId: serviceId)
        
        apiClient.makeRequest(route) { result in
            resultQueue.async {
                completion(result)
            }
        }
    }
    
	/// Writes data directly to user's library associated with configured contract.
	/// - Parameters:
	///   - data: The data to be written
	///   - metadata: The metadata describing the data to be written. See `RawFileMetadataBuilder` for details on building the metadata
	///   - credentials: The existing credentials for the contract.
	///   - resultQueue: The dispatch queue which the completion block will be called on. Defaults to main dispatch queue.
	///   - completion: Block called when writing data has complete with new or refreshed credentials, or any errors encountered.
    public func pushDataToLibrary(data: Data, metadata: RawFileMetadata, credentials: Credentials, resultQueue: DispatchQueue = .main, completion: @escaping (Credentials, Result<Void, SDKError>) -> Void) {
		validateOrRefreshCredentials(credentials) { result in
			switch result {
			case .success(let refreshedCredentials):
				self.writeDirect(data: data, metadata: metadata, credentials: refreshedCredentials, completion: completion)
			
			case .failure(let error):
				resultQueue.async {
					completion(credentials, .failure(error))
				}
			}
		}
	}
    
    /// Writes data to the authorized provider.
    /// - Parameters:
    ///   - payload: The data to be pushed to the provider.
    ///   - accountId: A unique reference to a selected account for PUSH, retrieved via the authorization endpoint.
    ///   - standard: The FHIR standard being used.
    ///   - version: The version of the FHIR standard, such as 'stu3' or '3.0.2'.
    ///   - credentials: The existing credentials for the contract.
    ///   - resultQueue: The dispatch queue on which the completion block will be called. Defaults to the main dispatch queue.
    ///   - completion: A block called upon completion with either the successful result or any errors encountered.
    public func pushDataToProvider(payload: Data, accountId: String, standard: String, version: String, credentials: Credentials, resultQueue: DispatchQueue = .main, completion: @escaping (Credentials, Result<Data, SDKError>) -> Void) {
        validateOrRefreshCredentials(credentials) { result in
            switch result {
            case .success(let refreshedCredentials):
                self.pushDataToProvider(payload: payload, accountId: accountId, standard: standard, version: version, credentials: refreshedCredentials, completion: completion)
                
            case .failure(let error):
                resultQueue.async {
                    completion(credentials, .failure(error))
                }
            }
        }
    }
   
    /// Deletes the user's library associated with the configured contract.
    ///
    /// Please note that if multiple contracts are linked to the same library,
    /// then `deleteUser` will also invalidate any credentials for those contracts.
    ///
    /// - Parameters:
    ///   - credentials: The existing credentials for the contract.
    ///   - resultQueue: The dispatch queue which the completion block will be called on. Defaults to main dispatch queue.
    ///   - completion: Block called on completion with any error encountered.
    public func deleteUser(credentials: Credentials, resultQueue: DispatchQueue = .main, completion: @escaping (Credentials, Result<Void, SDKError>) -> Void) {
        validateOrRefreshCredentials(credentials) { result in
            switch result {
            case .success(let refreshedCredentials):
                self.authService.deleteUser(oauthToken: refreshedCredentials.token) { result in
                    self.session = nil
                    resultQueue.async {
                        switch result {
                        case .success:
                            completion(refreshedCredentials, .success(()))
                        case .failure(let error):
                            completion(refreshedCredentials, .failure(error))
                        }
                    }
                }
            
            case .failure(let error):
                resultQueue.async {
                    completion(credentials, .failure(error))
                }
            }
        }
    }

    
    /// Deletes a specified service account from your library..
    ///
    /// This function is responsible for initiating the deletion process of a service account, identified by its unique `accountId`.
    /// It requires the client to provide valid `credentials` to authenticate the request. The deletion process is performed
    /// asynchronously, and the outcome is returned via the `completion` block.
    ///
    /// - Parameters:
    ///   - accountId: Service account entity identifier.
    ///   - credentials: The existing credentials for the contract.
    ///   - resultQueue: The dispatch queue which the completion block will be called on. Defaults to main dispatch queue.
    ///   - completion: Block called on completion with any error encountered.
    public func deleteAccount(accountId: String, credentials: Credentials, resultQueue: DispatchQueue = .main, completion: @escaping (Credentials, Result<Void, SDKError>) -> Void) {
        validateOrRefreshCredentials(credentials) { result in
            switch result {
            case .success(let refreshedCredentials):
                self.authService.deleteAccount(with: accountId, oauthToken: refreshedCredentials.token) { result in
                    resultQueue.async {
                        completion(refreshedCredentials, result)
                    }
                }

            case .failure(let error):
                resultQueue.async {
                    completion(credentials, .failure(error))
                }
            }
        }
    }


    /// Initiates the withdrawal of user consent for a specific service account.
    ///
    /// This function allows the user to withdraw previously granted consent for a service account.
    /// It requires the client to provide valid `credentials` for authentication and the `accountId`
    /// of the specific account for which the consent is being withdrawn. The process is asynchronous,
    /// and the outcome is communicated via the `completion` block.
    ///
    /// - Parameters:
    ///   - accountId: Service account entity identifier.
    ///   - credentials: The existing credentials for the contract.
    ///   - resultQueue: The dispatch queue which the completion block will be called on. Defaults to main dispatch queue.
    ///   - completion: Block called on completion with any error encountered.
    public func getRevokeAccountPermissionUrl(for accountId: String, credentials: Credentials, resultQueue: DispatchQueue = .main, completion: @escaping (Credentials, Result<Void, SDKError>) -> Void) {
        validateOrRefreshCredentials(credentials) { result in
            switch result {
            case .success(let refreshedCredentials):
                self.authService.revokeAccountPermission(with: accountId, oauthToken: refreshedCredentials.token) { result in
                    switch result {
                    case .success(let response):
                        self.consentManager.revokeAccount(revokeURL: response) { result in
                            switch result {
                            case .success:
                                resultQueue.async {
                                    completion(refreshedCredentials, .success(()))
                                }
                            case .failure(let error):
                                resultQueue.async {
                                    completion(refreshedCredentials, .failure(error))
                                }
                            }
                        }

                    case .failure(let error):
                        resultQueue.async {
                            completion(refreshedCredentials, .failure(error))
                        }
                    }
                }
            case .failure(let error):
                resultQueue.async {
                    completion(credentials, .failure(error))
                }
            }
        }
    }

    /// Clears cached data associated with a specific contract or all cached data if no contract ID is specified.
    /// This function provides a mechanism to clear various types of cached information, either globally or scoped to a particular contract.
    /// It affects session data, credentials, session caches, contract-specific time ranges, and locally cached request data.
    ///
    /// If a `contractId` is provided, the function clears data specifically related to that contract:
    /// - Clears session data held by `allFilesReader`.
    /// - Clears credentials related to the contract from `CredentialCache`.
    /// - Clears session information for the contract from `SessionCache`.
    /// - Clears cached time ranges for the contract from `ContractsCache`.
    /// - Removes requests for local data associated with the contract from `LocalDataCache`.
    ///
    /// If no `contractId` is provided, the function performs a general reset:
    /// - Resets the entire contracts cache and local data cache.
    ///
    /// - Parameter contractId: Optional. The ID of the contract for which to clear cached data. If nil, all caches are reset.
	public func clearCachedData(for contractId: String? = nil) {
		guard let contractId = contractId else {
			ContractsCache().reset()
			LocalDataCache().reset()
			return
		}
		
		allFilesReader?.clearSessionData()
		CredentialCache().clearCredentials(for: contractId)
		SessionCache().clearSession(for: contractId)
		ContractsCache().clearTimeRanges(for: contractId)
		LocalDataCache().removeRequestOfLocalData(for: contractId)
	}

    /// Gets the contract details for the specified contract.
    /// A contract is a configuration that defines the relationship between the SDK and your application.
    /// It contains information about what data the SDK can access and what operations it can perform.
    ///
    /// - Parameters:
    ///   - schemaVersion: The version of the contract schema to use.
    ///   - credentials: The existing credentials for the contract.
    ///   - resultQueue: The dispatch queue which the completion block will be called on. Defaults to main dispatch queue.
    ///   - completion: Block called upon completion with either the contract object or any errors encountered
    public func contractDetails(schemaVersion: String, credentials: Credentials, resultQueue: DispatchQueue = .main, completion: @escaping (Credentials, Result<ContractVersion5, SDKError>) -> Void) {
        validateOrRefreshCredentials(credentials) { result in
            switch result {
            case .success(let refreshedCredentials):
                guard let jwt = JWTUtility.basicRequestJWT(configuration: self.configuration) else {
                    completion(refreshedCredentials, .failure(SDKError.invalidBasicRequestJwt))
                    return
                }
                
                let route = ContractRoute(jwt: jwt, schemaVersion: schemaVersion)
                self.apiClient.makeRequest(route) { result in
                    switch result {
                    case .success(let response):
                        resultQueue.async {
                            self.certificateParser.parse(contractResponse: response) { result in
                                completion(refreshedCredentials, result)
                            }
                        }
                        
                    case .failure(let error):
                        resultQueue.async {
                            completion(refreshedCredentials, .failure(error))
                        }
                    }
                }
            case .failure(let error):
                resultQueue.async {
                    completion(credentials, .failure(error))
                }
            }
        }
    }
    
    /// The Portability Report is a report through which an individual is informed by their Individual's Service Provider about the health information that
    /// the individual has collected from providers in the digi.me application. This allows the individual to supplement another or
    /// a new personal health environment (PHE) with the same collection actions.
    /// - Parameters:
    ///   - serviceTypeName: Service type name, such as 'medmij'
    ///   - format: File format, such as 'xml'
    ///   - from: Start date in the format of a timestamp in seconds.
    ///   - to: End date in the format of a timestamp in seconds.
    ///   - credentials: The existing credentials for the contract.
    ///   - resultQueue: The dispatch queue on which the completion block will be called. Defaults to the main dispatch queue.
    ///   - completion: Block called upon completion with either the report data or any errors encountered.
    public func exportPortabilityReport(for serviceTypeName: String, format: String, from: TimeInterval, to: TimeInterval, credentials: Credentials, resultQueue: DispatchQueue = .main, completion: @escaping (Credentials, Result<Data, SDKError>) -> Void) {
        validateOrRefreshCredentials(credentials) { result in
            switch result {
            case .success(let refreshedCredentials):
                self.exportData(for: serviceTypeName, format: format, from: from, to: to, credentials: refreshedCredentials) { result in
                    self.session = nil
                    resultQueue.async {
                        completion(refreshedCredentials, result)
                    }
                }
                
            case .failure(let error):
                resultQueue.async {
                    completion(credentials, .failure(error))
                }
            }
        }
    }

    // MARK: - Discovery Services

    /// Get a list of possible services a user can add to their digi.me.
    /// If contract identifier is specified, then only those services relevant to the contract are retrieved, otherwise all services are retrieved.
    ///
    /// - Parameters:
    ///   - contractId: The contract identifier for which relevant available services are retrieved. If `nil` then all services are retrieved.
    ///   - filterAvailable: Filter all services by: “approved” && “production” && “available”
    ///   - resultQueue: The dispatch queue which the completion block will be called on. Defaults to main dispatch queue.
    ///   - completion: Block called upon completion with either the service list or any errors encountered
    public func availableServices(contractId: String?, filterAvailable: Bool = true, resultQueue: DispatchQueue = .main, completion: @escaping (Result<ServicesInfo, SDKError>) -> Void) {
        let route = ServicesRoute(contractId: contractId)
        apiClient.makeRequest(route) { result in
            switch result {
            case .success(let response):
                var availableServices = response.data.services

                if filterAvailable {
                    availableServices = availableServices.filter { $0.isAvailable }
                }

                let info = ServicesInfo(countries: response.data.countries, serviceGroups: response.data.serviceGroups, services: availableServices)
                resultQueue.async {
                    completion(.success(info))
                }

            case .failure(let error):
                resultQueue.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Discovery Sources

    /// Retrieves available source types from the API based on the given filter criteria.
    /// This function makes an asynchronous API request to fetch source types that can be onboarded for a contract.
    /// The result is returned on the specified `resultQueue` via a completion handler.
    ///
    /// - Parameters:
    ///   - filter: The filter criteria to apply for fetching source types.
    ///   - resultQueue: The dispatch queue on which the completion handler is called. Defaults to the main queue.
    ///   - completion: The completion handler that processes the result of the API call as either `SourceTypesInfo` or `SDKError`.
    public func availableSourceTypes(filter: SourceTypesRequestCriteria, resultQueue: DispatchQueue = .main, completion: @escaping (Result<[SourceType]?, SDKError>) -> Void) {
        guard let jwt = JWTUtility.basicRequestJWT(configuration: configuration) else {
            Logger.critical("Invalid data request JWT")
            completion(.failure(SDKError.invalidBasicRequestJwt))
            return
        }

        let route = SourceTypesRoute(jwt: jwt, payload: filter)
        self.apiClient.makeRequest(route) { result in
            switch result {
            case .success(let response):
                resultQueue.async {
                    completion(.success(response.data))
                }

            case .failure(let error):
                resultQueue.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Fetches available platforms related to the SDK services from the API using the specified filter.
    /// Ensures that a valid JWT is available before making the API request. If not, an error is returned.
    /// Asynchronous operation, results returned via a completion block on the specified dispatch queue.
    ///
    /// - Parameters:
    ///   - filter: The filter criteria to apply for fetching platform data.
    ///   - resultQueue: The queue on which completion handler is executed, defaults to main.
    ///   - completion: A closure that handles the result, returning either `PlatformsInfo` or `SDKError`.
    public func availablePlatforms(filter: SourcePlatformsRequestCriteria, resultQueue: DispatchQueue = .main, completion: @escaping (Result<[SourcePlatform]?, SDKError>) -> Void) {
        guard let jwt = JWTUtility.basicRequestJWT(configuration: configuration) else {
            Logger.critical("Invalid data request JWT")
            completion(.failure(SDKError.invalidBasicRequestJwt))
            return
        }

        let route = PlatformsRoute(jwt: jwt, payload: filter)
        self.apiClient.makeRequest(route) { result in
            switch result {
            case .success(let response):
                resultQueue.async {
                    completion(.success(response.data))
                }

            case .failure(let error):
                resultQueue.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Asynchronously retrieves available countries from the API according to the provided filter.
    /// Checks for a valid JWT before proceeding with the API request, failing which it returns an error.
    /// The function leverages asynchronous API calls to manage potentially large data sets efficiently.
    ///
    /// - Parameters:
    ///   - filter: Filter conditions to refine the country data retrieval.
    ///   - resultQueue: Queue to run the completion handler on, defaults to the main queue.
    ///   - completion: Completion handler that receives a `Result` containing `CountriesInfo` or `SDKError`.
    public func availableCountries(filter: SourceCountriesRequestCriteria, resultQueue: DispatchQueue = .main, completion: @escaping (Result<[SourceCountry]?, SDKError>) -> Void) {
        guard let jwt = JWTUtility.basicRequestJWT(configuration: configuration) else {
            Logger.critical("Invalid data request JWT")
            completion(.failure(SDKError.invalidBasicRequestJwt))
            return
        }

        let route = CountriesRoute(jwt: jwt, payload: filter)
        self.apiClient.makeRequest(route) { result in
            switch result {
            case .success(let response):
                resultQueue.async {
                    completion(.success(response.data))
                }

            case .failure(let error):
                resultQueue.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Fetches available categories from the API based on specified filter conditions.
    /// This function ensures authentication through JWT before making the request and handles errors appropriately.
    /// Results are returned asynchronously, allowing for effective handling of large data sets like thousands of healthcare providers.
    ///
    /// - Parameters:
    ///   - filter: Criteria used to filter the categories data.
    ///   - resultQueue: Dispatch queue for the completion handler, defaults to main.
    ///   - completion: Handler for successful or failed API responses, returns `CategoriesInfo` or `SDKError`.
    public func availableCategories(filter: SourceCategoriesRequestCriteria, resultQueue: DispatchQueue = .main, completion: @escaping (Result<[ServiceGroupType]?, SDKError>) -> Void) {
        guard let jwt = JWTUtility.basicRequestJWT(configuration: configuration) else {
            Logger.critical("Invalid data request JWT")
            completion(.failure(SDKError.invalidBasicRequestJwt))
            return
        }

        let route = CategoriesRoute(jwt: jwt, payload: filter)
        self.apiClient.makeRequest(route) { result in
            switch result {
            case .success(let response):
                resultQueue.async {
                    completion(.success(response.data))
                }

            case .failure(let error):
                resultQueue.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Obtains available sources using a given filter, with support for pagination via limit and offset.
    /// Prior to fetching, it checks for the presence of a valid JWT. On failure, it immediately returns an error.
    /// Designed to support efficient data delivery for potentially large numbers of sources by leveraging asynchronous operations.
    ///
    /// - Parameters:
    ///   - filter: Filter that includes optional pagination and sorting parameters to refine the sources retrieval.
    ///   - resultQueue: Queue to run the completion handler, typically the main queue.
    ///   - completion: Block to handle the API response, providing `SourcesInfo` or `SDKError`.
    public func availableSources(filter: SourceRequestCriteria, resultQueue: DispatchQueue = .main, completion: @escaping (Result<SourcesInfo, SDKError>) -> Void) {
        guard let jwt = JWTUtility.basicRequestJWT(configuration: configuration) else {
            Logger.critical("Invalid data request JWT")
            completion(.failure(SDKError.invalidBasicRequestJwt))
            return
        }

        let route = SourcesRoute(jwt: jwt, payload: filter)
        self.apiClient.makeRequest(route) { result in
            switch result {
            case .success(let response):
                resultQueue.async {
                    completion(.success(response))
                }

            case .failure(let error):
                resultQueue.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Provisional Cloud Storage

    /// Creates a provisional storage for the given contract.
    /// - Parameters:
    ///   - resultQueue: The dispatch queue which the download handler and completion blocks will be called on. Defaults to main dispatch queue.
    ///   - completion: A completion handler that is called with the result of the operation.
    public func createProvisionalStorage(resultQueue: DispatchQueue = .main, completion: @escaping (Result<StorageConfig, SDKError>) -> Void) {
        guard let jwt = JWTUtility.basicRequestJWT(configuration: configuration) else {
            Logger.critical("Invalid data request JWT")
            completion(.failure(SDKError.invalidBasicRequestJwt))
            return
        }

        let route = StorageCreateRoute(jwt: jwt)
        self.apiClient.makeRequest(route) { result in
            switch result {
            case .success(let response):
                resultQueue.async {
                    completion(.success(response))
                }

            case .failure(let error):
                resultQueue.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Retrieves the provisional storage configuration for a given contract identifier.
    /// Provisional storage is a space on the server created during the onboarding of a new user,
    /// which includes creating the user's library.
    /// - Parameters:
    ///   - credentials: The existing credentials for the contract.
    ///   - resultQueue: The dispatch queue on which the download handler and completion blocks will be called. Defaults to the main dispatch queue.
    ///   - completion: A completion handler that is called with the credentials and the result of the storage configuration retrieval.
    public func retrieveProvisionalStorage(credentials: Credentials, resultQueue: DispatchQueue = .main, completion: @escaping (Credentials, Result<StorageConfig, SDKError>) -> Void) {
        guard
            let session = session,
            session.isValid else {
            return completion(credentials, .failure(.invalidSession))
        }

        validateOrRefreshCredentials(credentials) { result in
            switch result {
            case .success(let refreshedCredentials):

                guard let jwt = JWTUtility.dataRequestJWT(accessToken: credentials.token.accessToken.value, configuration: self.configuration) else {
                    Logger.critical("Invalid data request JWT")
                    completion(refreshedCredentials, .failure(SDKError.invalidBasicRequestJwt))
                    return
                }

                let route = StorageRetrieveRoute(jwt: jwt)
                self.apiClient.makeRequest(route) { result in
                    switch result {
                    case .success(let response):
                        resultQueue.async {
                            completion(refreshedCredentials, .success(response))
                        }

                    case .failure(let error):
                        resultQueue.async {
                            completion(refreshedCredentials, .failure(error))
                        }
                    }
                }
            case .failure(let error):
                resultQueue.async {
                    completion(credentials, .failure(error))
                }
            }
        }
    }

    /// Reads the list of storage files from a provisional cloud storage instance.
    ///
    /// This function is part of the SDK's capabilities to interact with a cloud storage instance
    /// created and managed within the context of an App client's credentials. It supports operations
    /// essential for apps to handle user data before users are fully onboarded
    /// to digi.me. The function allows for listing files stored under a specific path within the app's cloud storage instance.
    ///
    /// - Parameters:
    ///   - storageId: The unique identifier for the cloud storage instance. This ID is typically obtained after creating a cloud instance through the SDK or via direct integration.
    ///   - path: An optional path to a specific directory or file in the cloud storage. If not provided, the root directory is assumed. This allows for scoped access to a subset of files.
    ///   - recursive: A Boolean value that determines whether the listing should include all subdirectories recursively. If `false`, only the contents of the specified path (or root) are listed. Defaults to `false`.
    ///   - resultQueue: The dispatch queue on which the completion handler is executed. This allows for flexibility in UI thread handling and integration within different parts of an app. Defaults to the main queue.
    ///   - completion: A closure that is called upon the completion of the file listing request. It returns a `Result` type which will either contain a `StorageFileList` on success or an `SDKError` on failure.
    public func readStorageFileList(storageId: String, path: String? = nil, recursive: Bool = false, resultQueue: DispatchQueue = .main, completion: @escaping (Result<StorageFileList, SDKError>) -> Void) {
        guard let jwt = JWTUtility.createCloudJWT(configuration: self.configuration) else {
            Logger.critical("Invalid data request JWT")
            completion(.failure(SDKError.invalidBasicRequestJwt))
            return
        }

        let route = StorageListFilesRoute(jwt: jwt, storageId: storageId, applicationId: self.configuration.appId, formatedPath: path, recursive: recursive)
        self.storageClient.makeRequest(route) { result in
            resultQueue.async {
                completion(result)
            }
        }
    }

    /// Uploads a file to storage.
    /// - Parameters:
    ///   - storageId: The ID of the storage to upload to.
    ///   - fileName: The name of the file to upload.
    ///   - data: The data of the file to upload.
    ///   - path: An optional path to a specific directory or file in the cloud storage. If not provided, the root directory is assumed. This allows for scoped access to a subset of files.
    ///   - resultQueue: The dispatch queue on which the completion handler is executed. This allows for flexibility in UI thread handling and integration within different parts of an app. Defaults to the main queue.
    ///   - completion: A completion handler with the result of the file upload.
    /// - Returns: A `URLSessionUploadTask` object that allows for controlling the upload, such as pausing, resuming, and canceling the task.
    @discardableResult
    public func uploadStorageFileTask(storageId: String, fileName: String, data: Data, path: String? = nil, resultQueue: DispatchQueue = .main, completion: @escaping (Result<StorageUploadFileInfo, SDKError>) -> Void) -> URLSessionUploadTask? {
        guard
            let payload = try? Crypto.encrypt(inputData: data, privateKeyData: configuration.privateKeyData),
            let jwt = JWTUtility.createCloudJWT(configuration: self.configuration) else {
            Logger.critical("Invalid data request JWT")
            completion(.failure(SDKError.invalidBasicRequestJwt))
            return nil
        }

        let route = StorageUploadFileRoute(jwt: jwt, storageId: storageId, applicationId: configuration.appId, fileName: fileName, formatedPath: path)
        return self.storageClient.makeRequestFileUpload(route, uploadData: payload) { result in
            resultQueue.async {
                completion(result)
            }
        }
    }

    /// Uploads a file to storage.
    /// - Parameters:
    ///   - storageId: The ID of the storage to upload to.
    ///   - fileName: The name of the file to upload.
    ///   - data: The data of the file to upload.
    ///   - path: An optional path to a specific directory or file in the cloud storage. If not provided, the root directory is assumed. This allows for scoped access to a subset of files.
    ///   - resultQueue: The dispatch queue on which the completion handler is executed. This allows for flexibility in UI thread handling and integration within different parts of an app. Defaults to the main queue.
    ///   - completion: A completion handler with the result of the file upload.
    public func uploadStorageFile(storageId: String, fileName: String, data: Data, path: String? = nil, resultQueue: DispatchQueue = .main, completion: @escaping (Result<StorageUploadFileInfo, SDKError>) -> Void) {
        resultQueue.async {
            self.uploadStorageService.upload(storageId: storageId, fileName: fileName, data: data, path: path, completion: completion)
        }
    }

    /// Deletes a file from storage.
    /// - Parameters:
    ///   - storageId: The ID of the storage to delete from.
    ///   - fileName: The name of the file to delete.
    ///   - path: An optional path to a specific directory or file in the cloud storage. If not provided, the root directory is assumed. This allows for scoped access to a subset of files.
    ///   - resultQueue: The dispatch queue on which the completion handler is executed. This allows for flexibility in UI thread handling and integration within different parts of an app. Defaults to the main queue.
    ///   - completion: A completion handler with the result of the file deletion.
    public func deleteStorageFile(storageId: String, fileName: String, path: String? = nil, resultQueue: DispatchQueue = .main, completion: @escaping (Result<Void, SDKError>) -> Void) {
        guard let jwt = JWTUtility.createCloudJWT(configuration: self.configuration) else {
            Logger.critical("Invalid data request JWT")
            completion(.failure(SDKError.invalidBasicRequestJwt))
            return
        }

        let route = StorageDeleteFileRoute(jwt: jwt, storageId: storageId, applicationId: configuration.appId, fileName: fileName, formatedPath: path)
        self.storageClient.makeRequest(route) { result in
            resultQueue.async {
                completion(result)
            }
        }
    }

    /// Deletes a folder or file from storage. This will delete all files that belong to the specified folder.
    /// You can specify paths like:
    /// - "/somefolder/": Deletes a folder and all its contents.
    /// - "/somefolder/somesubfolder/": Deletes a subfolder and all its contents.
    /// - "/": Deletes everything in the storage.
    /// - Parameters:
    ///   - storageId: The ID of the storage to delete from.
    ///   - path: A path or a directory name in the cloud storage you wish to delete.
    ///   - resultQueue: The dispatch queue on which the completion handler is executed. This allows for flexibility in UI thread handling and integration within different parts of an app. Defaults to the main queue.
    ///   - completion: A completion handler with the result of the file or folder deletion.
    public func deleteStorageFolder(storageId: String, path: String, resultQueue: DispatchQueue = .main, completion: @escaping (Result<Void, SDKError>) -> Void) {
        guard let jwt = JWTUtility.createCloudJWT(configuration: self.configuration) else {
            Logger.critical("Invalid data request JWT")
            completion(.failure(SDKError.invalidBasicRequestJwt))
            return
        }

        let route = StorageDeleteFolderRoute(jwt: jwt, storageId: storageId, applicationId: configuration.appId, formatedPath: path)
        self.storageClient.makeRequest(route) { result in
            resultQueue.async {
                completion(result)
            }
        }
    }

    /// Downloads a file from storage.
    /// - Parameters:
    ///   - storageId: The ID of the storage to download from.
    ///   - fileName: The name of the file to download.
    ///   - path: An optional path to a specific directory or file in the cloud storage. If not provided, the root directory is assumed. This allows for scoped access to a subset of files.
    ///   - resultQueue: The dispatch queue on which the completion handler is executed. This allows for flexibility in UI thread handling and integration within different parts of an app. Defaults to the main queue.
    ///   - completion: A completion handler with the result of the file download.
    /// - Returns: A `URLSessionDownloadTask` object that allows for controlling the download, such as pausing, resuming, and canceling the task.
    public func downloadStorageFileTask(storageId: String, fileName: String, path: String? = nil, resultQueue: DispatchQueue = .main, completion: @escaping (Result<Data?, SDKError>) -> Void) -> URLSessionDownloadTask? {
        guard let jwt = JWTUtility.createCloudJWT(configuration: self.configuration) else {
            Logger.critical("Invalid data request JWT")
            completion(.failure(SDKError.invalidBasicRequestJwt))
            return nil
        }

        let route = StorageFileRoute(jwt: jwt, storageId: storageId, applicationId: configuration.appId, fileName: fileName, formatedPath: path)
        return self.storageClient.makeRequestFileDownload(route) { result in
            switch result {
            case .success(let encryptedFile):
                do {
                    let file = try Crypto.decrypt(encryptedBase64EncodedData: encryptedFile, privateKeyData: self.configuration.privateKeyData, dataIsHashed: false)
                    resultQueue.async {
                        completion(.success(file))
                    }
                }
                catch {
                    resultQueue.async {
                        completion(.failure(.errorDecryptingResponse))
                    }
                }

            case .failure(let error):
                resultQueue.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Downloads a file from storage.
    /// - Parameters:
    ///   - storageId: The ID of the storage to download from.
    ///   - fileName: The name of the file to download.
    ///   - path: An optional path to a specific directory or file in the cloud storage. If not provided, the root directory is assumed. This allows for scoped access to a subset of files.
    ///   - resultQueue: The dispatch queue on which the completion handler is executed. This allows for flexibility in UI thread handling and integration within different parts of an app. Defaults to the main queue.
    ///   - completion: A completion handler with the result of the file download.
    public func downloadStorageFile(storageId: String, fileName: String, path: String? = nil, resultQueue: DispatchQueue = .main, completion: @escaping (Result<Data, SDKError>) -> Void) {
        resultQueue.async {
            self.downloadStorageService.downloadFile(storageId: storageId, fileName: fileName, configuration: self.configuration, filePath: path, completion: completion)
        }
    }

    // MARK: - Apple Health

    public func addTestData(completion: @escaping (Result<Bool, SDKError>) -> Void) {
#if targetEnvironment(simulator)
		healthSerivce?.addTestData { success, error in
            if success {
                completion(.success(success))
            }
            else {
                completion(.failure(.other))
            }
        }
#endif
    }
    
    // MARK: - Private
    
    private func readAccounts(credentials: Credentials, completion: @escaping (Result<[SourceAccountData], SDKError>) -> Void) {
        guard let jwt = JWTUtility.dataRequestJWT(accessToken: credentials.token.accessToken.value, configuration: configuration) else {
            return completion(.failure(.errorCreatingDataRequestJwt))
        }
        
        let route = ConnectedAccountsRoute(jwt: jwt)
        apiClient.makeRequest(route) { result in
            switch result {
            case .success(var accounts):
                if LocalDataCache().isDeviceDataRequested(for: self.configuration.contractId) {
                    if let accountData = self.healthAccountData {
                        accounts.append(accountData)
                    }
                    completion(.success(accounts))
                }
                else {
                    completion(.success(accounts))
                }
            case .failure(let error):
                if LocalDataCache().isDeviceDataRequested(for: self.configuration.contractId) {
                    if let accountData = self.healthAccountData {
                        completion(.success([accountData]))
                    }
                }
                else {
                    completion(.failure(error))
                }
            }
        }
    }
	
	private func writeDirect(data: Data, metadata: RawFileMetadata, credentials: Credentials, completion: @escaping (Credentials, Result<Void, SDKError>) -> Void) {
		uploadService.uploadFileDirect(data: data, metadata: metadata, credentials: credentials) { result in
			switch result {
			case .success:
				completion(credentials, .success(()))
			case .failure(let error):
				// We should be pre-emptively catching the situation where the access token has expired,
				// but just in case we should react to server message
				switch error {
				case .httpResponseError(statusCode: 401, apiError: let apiError) where apiError?.code == "InvalidToken":
					self.refreshTokens(credentials: credentials) { refreshResult in
						switch refreshResult {
						case .success(let refreshedCredentials):
							self.writeDirect(data: data, metadata: metadata, credentials: refreshedCredentials, completion: completion)
						case .failure(let error):
							completion(credentials, .failure(error))
						}
					}
				default:
					completion(credentials, .failure(error))
				}
			}
		}
	}
    
    private func pushDataToProvider(payload: Data, accountId: String, standard: String, version: String, credentials: Credentials, completion: @escaping (Credentials, Result<Data, SDKError>) -> Void) {
        guard let jwt = JWTUtility.dataRequestJWT(accessToken: credentials.token.accessToken.value, configuration: configuration) else {
            return completion(credentials, .failure(.errorCreatingDataRequestJwt))
        }

        let route = PushDataToProviderRoute(jwt: jwt, accountId: accountId, standard: standard, version: version, payload: payload)
        apiClient.makeRequest(route) { result in
            completion(credentials, result)
        }
    }
    
    private func exportData(for serviceTypeName: String, format: String, from: TimeInterval, to: TimeInterval, credentials: Credentials, completion: @escaping (Result<Data, SDKError>) -> Void) {
        guard let jwt = JWTUtility.dataRequestJWT(accessToken: credentials.token.accessToken.value, configuration: configuration) else {
            return completion(.failure(.errorCreatingRequestJwtToExportReport))
        }
        
        let route = ExportReportDataRoute(jwt: jwt, serviceTypeName: serviceTypeName, format: format, from: from, to: to)
        apiClient.makeRequest(route) { result in
            completion(result)
        }
    }
    
    // MARK: - Auth & Refresh
    
    // Auth - needs app to be able to receive response via URL
    private func beginAuth(serviceId: Int?, sampleDataSetId: String? = nil, sampleDataAutoOnboard: Bool? = nil, includeSampleDataOnlySources: Bool? = false, readOptions: ReadOptions?, linkToContractWithCredentials linkCredentials: Credentials?, onlyPushServices: Bool = false, storageRef: String? = nil, completion: @escaping (Result<Credentials, SDKError>) -> Void) {

        // Ensure we don't have any session left over from previous
        session = nil
                
        authService.requestPreAuthorizationCode(readOptions: readOptions, accessToken: linkCredentials?.token.accessToken.value) { result in
            switch result {
            case .success(let response):
                self.session = response.session
                self.performAuth(preAuthResponse: response, serviceId: serviceId, onlyPushServices: onlyPushServices, sampleDataSetId: sampleDataSetId, sampleDataAutoOnboard: sampleDataAutoOnboard, includeSampleDataOnlySources: includeSampleDataOnlySources, storageRef: storageRef, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // Request read session by triggering source sync
    private func triggerSourceSync(credentials: Credentials, readOptions: ReadOptions?, completion: @escaping (Credentials, Result<Void, SDKError>) -> Void) {
        guard let jwt = JWTUtility.dataRequestJWT(accessToken: credentials.token.accessToken.value, configuration: configuration) else {
            return completion(credentials, .failure(.errorCreatingRequestJwtToTriggerData))
        }

		apiClient.makeRequest(TriggerSyncRoute(jwt: jwt, readOptions: readOptions)) { result in
            switch result {
            case .success(let response):
                self.session = response.session
                completion(credentials, .success(Void()))

            case .failure(let error):
                // We should be pre-emptively catching the situation where the access token has expired,
                // but just in case we should react to server message
                switch error {
                case .httpResponseError(statusCode: 401, apiError: let apiError) where apiError?.code == "InvalidToken":
                    self.refreshTokens(credentials: credentials) { refreshResult in
                        switch refreshResult {
                        case .success(let refreshedCredentials):
                            self.triggerSourceSync(credentials: refreshedCredentials, readOptions: readOptions, completion: completion)
                        case .failure(let error):
                            completion(credentials, .failure(error))
                        }
                    }
                default:
                    completion(credentials, .failure(error))
                }
            }
        }
    }
        
    private func validateOrRefreshCredentials(_ credentials: Credentials?, completion: @escaping (Result<Credentials, SDKError>) -> Void) {
        // Check we have credentials
        guard let credentials = credentials else {
            return completion(.failure(SDKError.authorizationRequired))
        }
        
        guard credentials.token.accessToken.isValid else {
            return refreshTokens(credentials: credentials, completion: completion)
        }
        
        completion(.success(credentials))
    }
    
    private func refreshTokens(credentials: Credentials, completion: @escaping (Result<Credentials, SDKError>) -> Void) {
        guard credentials.token.refreshToken.isValid else {
            return reauthorize(credentials: credentials, completion: completion)
        }
        
        authService.renewAccessToken(oauthToken: credentials.token) { result in
            switch result {
            case .success(let response):
                let newCredentials = Credentials(token: response, writeAccessInfo: credentials.writeAccessInfo)
                completion(.success(newCredentials))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func reauthorize(accessToken: OAuthToken.Token, completion: @escaping (Result<Credentials, SDKError>) -> Void) {
        authService.requestPreAuthorizationCode(readOptions: nil, accessToken: accessToken.value) { result in
            switch result {
            case .success(let response):
                self.session = response.session
                self.performAuth(preAuthResponse: response, serviceId: nil, completion: completion)

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func performAuth(preAuthResponse: TokenSessionResponse, serviceId: Int?, onlyPushServices: Bool = false, sampleDataSetId: String? = nil, sampleDataAutoOnboard: Bool? = nil, includeSampleDataOnlySources: Bool? = nil, storageRef: String? = nil, completion: @escaping (Result<Credentials, SDKError>) -> Void) {
        consentManager.requestUserConsent(preAuthCode: preAuthResponse.token, serviceId: serviceId, onlyPushServices: onlyPushServices, sampleDataSetId: sampleDataSetId, sampleDataAutoOnboard: sampleDataAutoOnboard, includeSampleDataOnlySources: includeSampleDataOnlySources, storageRef: storageRef) { result in
            switch result {
            case .success(let response):
                self.exchangeToken(authResponse: response, completion: completion)

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    private func exchangeToken(authResponse: ConsentResponse, completion: @escaping (Result<Credentials, SDKError>) -> Void) {
        authService.requestTokenExchange(authCode: authResponse.authorizationCode) { result in
            switch result {
            case .success(let response):
                let newCredentials = Credentials(token: response, writeAccessInfo: authResponse.writeAccessInfo, accountReference: authResponse.accountReference)
                completion(.success(newCredentials))

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Utils
    
    private func validateClient() -> SDKError? {
		#if !DEBUG
        guard let urlTypes = Bundle.main.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]] else {
            return SDKError.noUrlScheme
        }
        
        let urlSchemes = urlTypes.compactMap { $0["CFBundleURLSchemes"] as? [String] }.flatMap { $0 }
        if !urlSchemes.contains("digime-ca-\(configuration.appId)") {
            return SDKError.noUrlScheme
        }
        
        if configuration.appId == "YOUR_APP_ID" {
            return SDKError.invalidAppId
        }
		#endif
        return nil
    }
    
    private func setupLogger() {
        let argonLogger = FileUploadService(apiClient: apiClient, configuration: configuration)

        let handler: LogHandler = { level, message, file, function, line, metadata in
            NSLog("[DigiMeSDK] [\(level.rawValue.uppercased())] \(message)")
            
            guard
                level == .mixpanel,
				let meta = metadata as? LogEventMeta else {
                return
            }
            
            argonLogger.uploadLog(logName: message, metadata: meta) { result in
                switch result {
                case .failure(let sdkerror):
					NSLog("[DigiMeSDK] error uploading logs: \(sdkerror)")
                default:
                    break
                }
            }
        }

        DigiMe.setLogHandler(handler)
    }
}
