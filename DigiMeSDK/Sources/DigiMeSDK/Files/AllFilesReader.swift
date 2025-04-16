//
//  AllFilesReader.swift
//  DigiMeSDK
//
//  Created on 13/09/2021.
//  Copyright © 2021 digi.me Limited. All rights reserved.
//

import DigiMeCore
import Foundation

class AllFilesReader {
    
    private let sessionCache = SessionCache()
    @Atomic private var isFetchingSessionData = false
    private var fileListCache = FileListCache()
    private var sessionError: SDKError?
    private var sessionFileList: FileList?
	private var deviceDataFiles: [FileListItem]?
    private var stalePollCount = 0
    private var pendingStatusCount = 0
    private var syncStartTime: Date?

    private let apiClient: APIClient
    private let configuration: Configuration
	private let credentials: Credentials
    private let healthService: HealthKitServiceProtocol?
    private let healthFilesDataService: HealthKitFilesDataServiceProtocol?
	private let certificateParser: CertificateParser
	private let contractsCache: ContractsCache
    private var sessionDataCompletion: ((Result<FileList, SDKError>) -> Void)?
    private var sessionContentHandler: ((Result<File, SDKError>) -> Void)?
    private var readOptions: ReadOptions?
	
    private lazy var downloadService: FileDownloadService = {
        FileDownloadService(apiClient: apiClient, dataDecryptor: DataDecryptor(configuration: configuration))
    }()
    
    private enum Defaults {
        static let maxStalePolls = 100
        static let maxPendingStatusCount = 20
        static let pollInterval = 3
        static let maxSyncDuration: TimeInterval = 5 * 60 // 5 minutes
    }
    
    init(apiClient: APIClient,
         credentials: Credentials,
         certificateParser: CertificateParser,
         contractsCache: ContractsCache,
         configuration: Configuration,
         healthService: HealthKitServiceProtocol?,
         healthFilesDataService: HealthKitFilesDataServiceProtocol?,
         readOptions: ReadOptions? = nil) {
        
        self.apiClient = apiClient
        self.credentials = credentials
        self.certificateParser = certificateParser
        self.contractsCache = contractsCache
        self.configuration = configuration
        self.healthService = healthService
        self.healthFilesDataService = healthFilesDataService
        self.readOptions = readOptions
    }
    
    private var session: Session? {
        get {
            sessionCache.session(for: configuration.contractId)
        }
        set {
            sessionCache.setSession(newValue, for: configuration.contractId)
        }
    }
    
    private var isSyncRunning: Bool {
		// Check if local data already collected and no remote services
		if
			LocalDataCache().isDeviceDataRequested(for: configuration.contractId),
			deviceDataFiles != nil,
			sessionFileList?.status.state == .pending {
			
			return false
		}
		
        // If no session file list, could be because we haven't received response yet, so assume is running
        return sessionFileList?.status.state.isRunning ?? true
    }
    
    func readAllFiles(downloadHandler: @escaping (Result<File, SDKError>) -> Void, completion: @escaping (Result<FileList, SDKError>) -> Void) {
        guard !isFetchingSessionData else {
            completion(.failure(SDKError.alreadyReadingAllFiles))
            return
        }

        self.sessionContentHandler = downloadHandler
        self.sessionDataCompletion = completion

        syncStartTime = Date()

		if LocalDataCache().isDeviceDataRequested(for: configuration.contractId) {
			self.beginFetchDeviceLocalData()
		}
		
        self.beginFileListPollingIfRequired()
    }
	
	func clearSessionData() {
		isFetchingSessionData = false
		
		fileListCache.reset()
		downloadService.cancel()
		downloadService.allDownloadsFinishedHandler = nil
		sessionError = nil
		stalePollCount = 0
        pendingStatusCount = 0
		deviceDataFiles = nil
        syncStartTime = nil
	}
    
    private func beginFileListPollingIfRequired() {
        isFetchingSessionData = true
        downloadService.allDownloadsFinishedHandler = {
            Logger.info("Finished downloading all files")
            self.evaluateSessionDataFetchProgress(schedulePoll: false)
        }
        refreshFileList()
        scheduleNextPoll()
    }
    
    private func refreshFileList() {
        guard
            let session = session,
            session.isValid else {
            
            // Cannot continue without valid session
            return completeSessionDataFetch(error: .invalidSession)
        }
        
		guard let jwt = JWTUtility.dataRequestJWT(accessToken: credentials.token.accessToken.value, configuration: configuration) else {
			completeSessionDataFetch(error: .errorCreatingDataRequestJwt)
			return
		}
		
		let route = FileListRoute(jwt: jwt, sessionKey: session.key)
        apiClient.makeRequest(route) { result in
            switch result {
            case .success(let fileList):
                let fileListDidChange = fileList != self.sessionFileList
                self.stalePollCount += fileListDidChange ? 0 : 1
                guard self.stalePollCount < Defaults.maxStalePolls else {
                    self.sessionError = SDKError.fileListPollingTimeout
                    return
                }
                
                // If subsequent fetch clears the error (stale one or otherwise) - great, no need to report it back up the chain
                self.sessionError = nil
                self.sessionFileList = fileList
                let newItems = self.fileListCache.newItems(from: fileList.files ?? [])
                
                self.handleNewFileListItems(newItems)

            case .failure(let error):
                // If the error occurred we don't want to terminate right away
                // There could still be files downloading. Instead, we will store the sessionError
                // which will be forwarded in completion once all file have been downloaded
                
                // If no files are being downloaded, we can terminate session fetch right away
                if !self.downloadService.isDownloadingFiles {
                    self.completeSessionDataFetch(error: error)
                }
                
                self.sessionError = error
            }
        }
    }
    
    private func handleNewFileListItems(_ items: [FileListItem]) {
        guard !items.isEmpty else {
            return
        }
        
        Logger.info("Found new files to sync: \(items.count)")
        fileListCache.add(items: items)
        
        // If contentHandler is not provided, no need to download
        guard let sessionContentHandler = sessionContentHandler else {
            return
        }
        
        guard
            let session = session,
            session.isValid else {
            
            // Cannot continue without valid session
            return completeSessionDataFetch(error: .invalidSession)
        }
        
        items.forEach { item in
            Logger.info("Adding file to download queue: \(item.name)")
			self.downloadService.downloadFile(fileId: item.name, sessionKey: session.key, credentials: credentials, configuration: configuration, updatedDate: item.updatedDate, completion: sessionContentHandler)
        }
    }
    
    private func scheduleNextPoll() {
        DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(Defaults.pollInterval)) { [weak self] in
            self?.evaluateSessionDataFetchProgress(schedulePoll: true)
        }
    }
    
    private func completeSessionDataFetch(error: SDKError?) {
		if let error = error {
			sessionDataCompletion?(.failure(error))
		}
		else if let localFiles = deviceDataFiles {
			// local data already collected
			var existing = sessionFileList?.files ?? []
			existing.append(contentsOf: localFiles)
			let status = sessionFileList?.status
			let fileList = FileList(files: existing, status: status!)
			sessionDataCompletion?(.success(fileList))
		}
		else if LocalDataCache().isDeviceDataRequested(for: configuration.contractId), deviceDataFiles?.isEmpty ?? true {
			// local data is not yet collected
			beginFetchDeviceLocalData()
			return
		}
		else if let list = sessionFileList {
			sessionDataCompletion?(.success(list))
		}
								   
        clearSessionData()
    }
    
    private func evaluateSessionDataFetchProgress(schedulePoll: Bool) {
        guard isFetchingSessionData else {
            return
        }
        
        Logger.info("Sync state - \(sessionFileList != nil ? sessionFileList!.status.state.rawValue : "unknown")")
        
        // Check if the status is pending and increment the counter
        if let status = sessionFileList?.status.state, status == .pending {
            pendingStatusCount += 1
            if pendingStatusCount >= Defaults.maxPendingStatusCount {
                Logger.info("Sync has been pending for too long. Stopping sync.")
                completeSessionDataFetch(error: .syncPendingTimeout)
                return
            }
        } 
        else {
            // Reset the counter if the status is not pending
            pendingStatusCount = 0
        }

        if let startTime = syncStartTime, Date().timeIntervalSince(startTime) > Defaults.maxSyncDuration {
            Logger.info("Sync has exceeded the maximum duration. Stopping sync.")
            completeSessionDataFetch(error: .syncTimeout)
            return
        }

        // If sessionError is not nil, then syncState is irrelevant, as it will be the previous successful fileList call.
        if (sessionError != nil || !isSyncRunning) && !self.downloadService.isDownloadingFiles {
            Logger.info("Finished fetching session data.")
            completeSessionDataFetch(error: sessionError)
            return
        }
        else if schedulePoll {
            scheduleNextPoll()
        }
        
        // Not checking sessionError here on purpose. If we are here, then there are files still being downloaded
        // so we may as well poll the file list again, just in case the error clears.
        if isSyncRunning {
            refreshFileList()
        }
    }
	
	private func beginFetchDeviceLocalData() {
		let appId = configuration.appId
		let contractId = configuration.contractId
		contractTimeRangeLimits(appId: appId, contractId: contractId) { result in
			switch result {
			case .success(let limits):
				let deviceDataCompletion: (Result<[FileListItem], SDKError>) -> Void = { [weak self] result in
					switch result {
					case .success(let files):
						self?.deviceDataFiles = files
						self?.evaluateSessionDataFetchProgress(schedulePoll: false)
					case .failure(let error):
						self?.sessionDataCompletion?(.failure(error))
					}
				}
                self.healthFilesDataService?.queryData(from: limits.startDate, to: limits.endDate, downloadHandler: self.sessionContentHandler, completion: deviceDataCompletion)
			case .failure(let error):
                self.healthService?.reportErrorLog(error: error)
				self.sessionDataCompletion?(.failure(error))
			}
		}
	}
	
	private func contractTimeRangeLimits(appId: String, contractId: String, completion: @escaping (Result<TimeRangeLimits, SDKError>) -> Void) {
		guard
            let contractTimeRange = self.contractsCache.firstTimeRange(for: contractId) else {
            
            guard let jwt = JWTUtility.basicRequestJWT(configuration: configuration) else {
                completion(.failure(.errorCreatingDataRequestJwt))
                return
            }
            
            let route = ContractRoute(jwt: jwt, schemaVersion: "5.0.0")
			apiClient.makeRequest(route) { result in
				switch result {
				case .success(let response):
					self.certificateParser.parse(contractResponse: response) { certificateResult in
						switch certificateResult {
						case .success(let certificate):
							self.contractsCache.addTimeRanges(ranges: certificate.dataRequest?.timeRanges, for: contractId)
							let timeRangeResult = certificate.verifyTimeRange(readOptions: self.readOptions)
							switch timeRangeResult {
							case .success(let limits):
								completion(.success(limits))
							case .failure(let error):
								completion(.failure(error))
							}
						case .failure(let error):
							completion(.failure(error))
						}
					}
				case .failure(let error):
					completion(.failure(error))
				}
			}
			return
		}
		
		let limits = contractTimeRange.verifyTimeRange(readOptions: readOptions)
		completion(.success(limits))
	}
}
