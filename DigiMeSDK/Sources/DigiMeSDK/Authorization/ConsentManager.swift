//
//  ConsentManager.swift
//  DigiMeSDK
//
//  Created on 11/06/2021.
//  Copyright © 2021 digi.me Limited. All rights reserved.
//

import DigiMeCore
import Foundation
import SafariServices

final class ConsentManager: NSObject {
    private let configuration: Configuration
    private var userConsentCompletion: ((Result<ConsentResponse, SDKError>) -> Void)?
    private var addServiceCompletion: ((Result<Void, SDKError>) -> Void)?
    private var revokeAccountCompletion: ((Result<Void, SDKError>) -> Void)?
    private var safariViewController: SFSafariViewController?
	private var localServiceRequested = false
	
    private enum ResponseKey: String, Codable {
        case state
        case code
        case postboxId
        case publicKey
        case success
        case errorCode
        case accountReference
        case result
        case errorMessage

        private enum CodingKeys: String, CodingKey {
            case state
            case code
            case postboxId
            case publicKey
            case success
            case errorCode
            case accountReference
            case result
            case errorMessage = "error_message"
        }
    }
    
    private enum Action: String {
        case auth
        case service
        case revoke
    }

    init(configuration: Configuration) {
        self.configuration = configuration
    }
    
    func requestUserConsent(preAuthCode: String, serviceId: Int?, onlyPushServices: Bool = false, sampleDataSetId: String? = nil, sampleDataAutoOnboard: Bool? = nil, includeSampleDataOnlySources: Bool? = nil, storageRef: String? = nil, completion: @escaping ((Result<ConsentResponse, SDKError>) -> Void)) {
        guard Thread.current.isMainThread else {
            DispatchQueue.main.async {
                self.requestUserConsent(preAuthCode: preAuthCode, serviceId: serviceId, onlyPushServices: onlyPushServices, sampleDataSetId: sampleDataSetId, sampleDataAutoOnboard: sampleDataAutoOnboard, includeSampleDataOnlySources: includeSampleDataOnlySources, storageRef: storageRef, completion: completion)
            }
            return
        }
        
        userConsentCompletion = completion
        CallbackService.shared().setCallbackHandler(self)
		let baseUrl = self.configuration.baseUrl ?? APIConfig.baseUrl
        var components = URLComponents(string: "\(baseUrl)/apps/saas/authorize")!
        
        var percentEncodedQueryItems = [
            URLQueryItem(name: "code", value: preAuthCode),
        ]
        
        if let serviceId = serviceId {
			if !localServiceRequested {
				localServiceRequested = serviceId == DeviceOnlyServices.appleHealth.rawValue
			}
            percentEncodedQueryItems.append(URLQueryItem(name: "service", value: "\(serviceId)"))
        }
        
        if onlyPushServices {
            percentEncodedQueryItems.append(URLQueryItem(name: "sourceType", value: "push"))
        }
        
        if let sampleDataSetId = sampleDataSetId {
            percentEncodedQueryItems.append(URLQueryItem(name: "sampleDataSet", value: "\(sampleDataSetId)"))
        }
        
        if let sampleDataAutoOnboard = sampleDataAutoOnboard {
            percentEncodedQueryItems.append(URLQueryItem(name: "sampleDataAutoOnboard", value: "\(sampleDataAutoOnboard)"))
        }

        if let includeSampleDataOnlySources = includeSampleDataOnlySources, includeSampleDataOnlySources {
            percentEncodedQueryItems.append(URLQueryItem(name: "includeSampleDataOnlySources", value: "\(includeSampleDataOnlySources)"))
        }

        percentEncodedQueryItems.append(URLQueryItem(name: "lng", value: Locale.current.identifier))

        if let storageRef = storageRef {
            percentEncodedQueryItems.append(URLQueryItem(name: "storageRef", value: storageRef))
        }

        components.percentEncodedQueryItems = percentEncodedQueryItems
        open(url: components.url!)
    }

    func revokeAccount(revokeURL: String, completion: @escaping ((Result<Void, SDKError>) -> Void)) {
        guard Thread.current.isMainThread else {
            DispatchQueue.main.async {
                self.revokeAccount(revokeURL: revokeURL, completion: completion)
            }
            return
        }

        guard let url = URL(string: revokeURL) else {
            completion(Result.failure(SDKError.unknown(message: "Error creating revoke account url")))
            return
        }

        revokeAccountCompletion = completion
        CallbackService.shared().setCallbackHandler(self)
        open(url: url)
    }

    func addService(identifier: Int, token: String, sampleDataSetId: String? = nil, sampleDataAutoOnboard: Bool? = nil, includeSampleDataOnlySources: Bool? = nil, completion: @escaping ((Result<Void, SDKError>) -> Void)) {
        guard Thread.current.isMainThread else {
            DispatchQueue.main.async {
                self.addService(identifier: identifier, token: token, sampleDataSetId: sampleDataSetId, sampleDataAutoOnboard: sampleDataAutoOnboard, includeSampleDataOnlySources: includeSampleDataOnlySources, completion: completion)
            }
            return
        }
        
        addServiceCompletion = completion
        CallbackService.shared().setCallbackHandler(self)
		let baseUrl = self.configuration.baseUrl ?? APIConfig.baseUrl
        var components = URLComponents(string: "\(baseUrl)/apps/saas/onboard")!
        
		if !localServiceRequested {
			localServiceRequested = identifier == DeviceOnlyServices.appleHealth.rawValue
		}
		
        components.percentEncodedQueryItems = [
            URLQueryItem(name: "code", value: token),
            URLQueryItem(name: "service", value: "\(identifier)"),
        ]
        
        if let sampleDataSetId = sampleDataSetId {
            components.percentEncodedQueryItems?.append(URLQueryItem(name: "sampleDataSet", value: "\(sampleDataSetId)"))
        }
        
        if let sampleDataAutoOnboard = sampleDataAutoOnboard, sampleDataAutoOnboard {
            components.percentEncodedQueryItems?.append(URLQueryItem(name: "sampleDataAutoOnboard", value: "\(sampleDataAutoOnboard)"))
        }

        if let includeSampleDataOnlySources = includeSampleDataOnlySources, includeSampleDataOnlySources {
            components.percentEncodedQueryItems?.append(URLQueryItem(name: "includeSampleDataOnlySources", value: "\(includeSampleDataOnlySources)"))
        }

        open(url: components.url!)
    }
    
    func reauthService(accountRef: String, token: String, locale: String? = nil, completion: @escaping ((Result<Void, SDKError>) -> Void)) {
		guard Thread.current.isMainThread else {
			DispatchQueue.main.async {
                self.reauthService(accountRef: accountRef, token: token, locale: locale, completion: completion)
			}
			return
		}
		
		addServiceCompletion = completion
		CallbackService.shared().setCallbackHandler(self)
		let baseUrl = self.configuration.baseUrl ?? APIConfig.baseUrl
		var components = URLComponents(string: "\(baseUrl)/apps/saas/reauthorize")!
		
        let effectiveLocale = locale ?? Locale.current.languageCode ?? "en"
        
		components.percentEncodedQueryItems = [
			URLQueryItem(name: "code", value: token),
			URLQueryItem(name: "accountRef", value: accountRef),
            URLQueryItem(name: "locale", value: effectiveLocale),
		]
		
		open(url: components.url!)
	}
    
    func reauthUser(token: String, locale: String? = nil, triggerQuery: Bool? = nil, completion: @escaping ((Result<Void, SDKError>) -> Void)) {
        guard Thread.current.isMainThread else {
            DispatchQueue.main.async {
                self.reauthUser(token: token, locale: locale, completion: completion)
            }
            return
        }
        
        addServiceCompletion = completion
        CallbackService.shared().setCallbackHandler(self)
        let baseUrl = self.configuration.baseUrl ?? APIConfig.baseUrl
        var components = URLComponents(string: "\(baseUrl)/apps/saas/user-reauth")!
        
        var queryItems = [URLQueryItem(name: "code", value: token)]

        let effectiveLocale = locale ?? Locale.current.languageCode ?? "en"
        queryItems.append(URLQueryItem(name: "lng", value: effectiveLocale))

        if let triggerQuery = triggerQuery {
            queryItems.append(URLQueryItem(name: "triggerQuery", value: triggerQuery.description))
        }

        components.percentEncodedQueryItems = queryItems

        open(url: components.url!)
    }
	
    // MARK: - Private
    
    private func open(url: URL) {
        DispatchQueue.main.async {
			guard !self.configuration.authUsingExternalBrowser else {
				UIApplication.shared.open(url)
				return
			}
			
            let viewController = SFSafariViewController(url: url)
            viewController.delegate = self
            viewController.presentationController?.delegate = self
            viewController.dismissButtonStyle = .cancel
            self.safariViewController = viewController
            
            UIViewController.topMostViewController()?.present(viewController, animated: true, completion: nil)
        }
    }
    
    private func finishUserConsent(with result: Result<ConsentResponse, Error>) {
        guard Thread.current.isMainThread else {
            DispatchQueue.main.async {
                self.finishUserConsent(with: result)
            }
            return
        }
        
        guard localServiceRequested else {
            localServiceRequested = false
            reset()
            userConsentCompletion?(mapErrors(result: result))
            userConsentCompletion = nil
            return
        }
        
        LocalDataCache().requestLocalData(for: configuration.contractId)
        
        if let healthKitServiceClass = NSClassFromString("DigiMeHealthKit.HealthKitService") as? HealthKitServiceProtocol.Type {
            let healthKitServiceInstance = healthKitServiceClass.init()
            healthKitServiceInstance.requestAuthorization(typesToRead: [], typesToWrite: []) { _, _ in
                self.localServiceRequested = false
                self.reset()
                self.userConsentCompletion?(self.mapErrors(result: result))
                self.userConsentCompletion = nil
            }
        }
    }
    
    private func finishAddService(with result: Result<Void, Error>) {
        guard Thread.current.isMainThread else {
            DispatchQueue.main.async {
                self.finishAddService(with: result)
            }
            return
        }
        
        guard localServiceRequested else {
            localServiceRequested = false
            reset()
            addServiceCompletion?(mapErrors(result: result))
            addServiceCompletion = nil
            return
        }
        
        LocalDataCache().requestLocalData(for: configuration.contractId)
        if let healthKitServiceClass = NSClassFromString("DigiMeHealthKit.HealthKitService") as? HealthKitServiceProtocol.Type {
            let healthKitServiceInstance = healthKitServiceClass.init()
            healthKitServiceInstance.requestAuthorization(typesToRead: [], typesToWrite: []) { _, _ in
                self.localServiceRequested = false
                self.reset()
                self.addServiceCompletion?(self.mapErrors(result: result))
                self.addServiceCompletion = nil
            }
        }
    }
    
    private func finishRevokeAccount(with result: Result<Void, Error>) {
        guard Thread.current.isMainThread else {
            DispatchQueue.main.async {
                self.finishRevokeAccount(with: result)
            }
            return
        }

        reset()
        revokeAccountCompletion?(self.mapErrors(result: result))
        revokeAccountCompletion = nil
    }

    private func mapErrors<T>(result: Result<T, Error>) -> Result<T, SDKError> {
        return result.mapError { error in
            switch error {
            case ConsentError.userCancelled:
                return .authorizationCancelled
            case ConsentError.serviceOnboardError:
                return .addingServiceFailed
            case ConsentError.unexpectedError:
                return .unexpectedErrorWhenParsingConsentResponse
            case let err as ConsentError:
                return .authorizationFailed(code: err.rawValue)
            default:
                return .other
            }
        }
    }
    
    private func userCancelled() {
        guard Thread.current.isMainThread else {
            DispatchQueue.main.async {
                self.userCancelled()
            }
            return
        }
        
        reset()
        
        addServiceCompletion?(.failure(.authorizationCancelled))
        addServiceCompletion = nil
        
        userConsentCompletion?(.failure(.authorizationCancelled))
        userConsentCompletion = nil

        revokeAccountCompletion?(.failure(.authorizationCancelled))
        revokeAccountCompletion = nil
    }
    
    private func reset() {
		DispatchQueue.main.async {
			self.safariViewController?.delegate = nil
			self.safariViewController?.presentationController?.delegate = nil
			self.safariViewController = nil
		}
    }
    
    private func handleAuthAction(parameters: [String: String?], presentingViewController: UIViewController?) {
        let result: Result<ConsentResponse, Error>!
        defer {
			if let vc = presentingViewController {
				vc.dismiss(animated: true) {
					self.finishUserConsent(with: result)
				}
			}
			
			self.finishUserConsent(with: result)
        }
        
        guard let success = parameters[ResponseKey.success.rawValue] else {
            result = .failure(CallbackError.invalidCallbackParameters)
            return
        }
        
        switch success {
        case "true":
            result = processAuthSuccessCallback(parameters: parameters)
            
        case "false":
            let error = processErrorCallback(parameters: parameters)
            result = .failure(error)
            
        default:
            result = .failure(CallbackError.invalidCallbackParameters)
        }
    }
    
    private func handleServiceAction(parameters: [String: String?], presentingViewController: UIViewController?) {
        let result: Result<Void, Error>!
        defer {
			if let vc = presentingViewController {
				vc.dismiss(animated: true) {
					self.finishAddService(with: result)
				}
			}
			
			self.finishAddService(with: result)
        }
        
        guard let success = parameters[ResponseKey.success.rawValue] else {
            result = .failure(CallbackError.invalidCallbackParameters)
            return
        }
        
        switch success {
        case "true":
            result = .success(())
            
        case "false":
            let error = processErrorCallback(parameters: parameters)
            result = .failure(error)
            
        default:
            result = .failure(CallbackError.invalidCallbackParameters)
        }
    }

    private func handleRevokeAction(parameters: [String: String?], presentingViewController: UIViewController?) {
        let result: Result<Void, Error>!
        defer {
            if let vc = presentingViewController {
                vc.dismiss(animated: true) {
                    self.finishRevokeAccount(with: result)
                }
            }

            self.finishRevokeAccount(with: result)
        }

        guard let success = parameters[ResponseKey.result.rawValue] else {
            result = .failure(CallbackError.invalidCallbackParameters)
            return
        }

        switch success {
        case "success":
            result = .success(())

        case "failed":
            let error = processErrorCallback(parameters: parameters)
            result = .failure(error)

        default:
            result = .failure(CallbackError.invalidCallbackParameters)
        }
    }

    private func processAuthSuccessCallback(parameters: [String: String?]) -> Result<ConsentResponse, Error> {
        guard
            let status = parameters[ResponseKey.state.rawValue] as? String,
            let code = parameters[ResponseKey.code.rawValue] as? String else {
            return .failure(CallbackError.invalidCallbackParameters)
        }
        
        var writeAccessInfo: WriteAccessInfo?
        if
            let postboxId = parameters[ResponseKey.postboxId.rawValue] as? String,
            let publicKey = parameters[ResponseKey.publicKey.rawValue] as? String {
            writeAccessInfo = .init(postboxId: postboxId, publicKey: publicKey)
        }

		if localServiceRequested {
			LocalDataCache().requestLocalData(for: configuration.contractId)
		}
		
        let accountReference = parameters[ResponseKey.accountReference.rawValue] as? String
        let response = ConsentResponse(code: code, status: status, accountReference: accountReference, writeAccessInfo: writeAccessInfo)
        return .success(response)
    }
    
    private func processErrorCallback(parameters: [String: String?]) -> ConsentError {
        if
            let errorCode = parameters[ResponseKey.errorCode.rawValue] as? String,
            let error = ConsentError(rawValue: errorCode) {
            return error
        }

        if
            let errorMessage = parameters[ResponseKey.errorMessage.rawValue] as? String,
            let error = ConsentError(rawValue: errorMessage) {
            return error
        }

        return .unexpectedError

    }
}

extension ConsentManager: CallbackHandler {
    func canHandleAction(_ action: String) -> Bool {
        Action(rawValue: action) != nil
    }
    
    func handleAction(_ action: String, with parameters: [String: String?]) {
        CallbackService.shared().removeCallbackHandler(self)
        
		guard !configuration.authUsingExternalBrowser else {
			guard let actionToHandle = Action(rawValue: action) else {
				return
			}
			
			switch actionToHandle {
			case .auth:
				handleAuthAction(parameters: parameters, presentingViewController: nil)
			
			case .service:
				handleServiceAction(parameters: parameters, presentingViewController: nil)

            case .revoke:
                handleRevokeAction(parameters: parameters, presentingViewController: nil)
            }
			
			return
		}
		
        // User could have opened in Safari Browser and cancelled/completed authentication in SafariViewController
        // then cancelled/completed authentication again in Browser,
        // in which case we ignore any callback from Browser as app has already handled a callback.
        guard
            let viewController = safariViewController,
            viewController.isViewLoaded,
            viewController.view.window != nil,
            let presentingViewController = viewController.presentingViewController else {
            return
        }
        
        guard let actionToHandle = Action(rawValue: action) else {
            return
        }
        
        switch actionToHandle {
        case .auth:
            handleAuthAction(parameters: parameters, presentingViewController: presentingViewController)
        
        case .service:
            handleServiceAction(parameters: parameters, presentingViewController: presentingViewController)

        case .revoke:
            handleRevokeAction(parameters: parameters, presentingViewController: presentingViewController)
        }
    }
}

extension ConsentManager: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        guard controller === safariViewController else {
            return
        }
        
        userCancelled()
    }
}

extension ConsentManager: UIAdaptivePresentationControllerDelegate {
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard presentationController.presentedViewController === safariViewController else {
            return
        }
        
        userCancelled()
    }
}
