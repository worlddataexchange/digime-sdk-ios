//
//  ContractRoute.swift
//  DigiMeSDK
//
//  Created on 12/03/2022.
//  Copyright © 2022 digi.me Limited. All rights reserved.
//

import DigiMeCore
import Foundation

struct ContractRoute: Route {    
    typealias ResponseType = ContractResponse
    
    static let method = "GET"
    static let path = "permission-access/contract"
    
    var queryParameters: [URLQueryItem] {
        return [URLQueryItem(name: "schemaVersion", value: schemaVersion)]
    }
    
    var customHeaders: [String: String] {
        ["Authorization": "Bearer " + jwt]
    }
    
    let jwt: String
    let schemaVersion: String
    
    func parseResponse(data: Data, headers: [AnyHashable: Any]) throws -> ResponseType {
        return try data.decoded(dateDecodingStrategy: .millisecondsSince1970) as ResponseType
    }
}

