//
//  SourceFetchFilter.swift
//  DigiMeCore
//
//  Created on 30/10/2024.
//  Copyright © 2024 digi.me Limited. All rights reserved.
//

import Foundation

/// Filter structure for fetching source data
public struct SourceFetchFilter: Codable {
    /// Account information containing array of account IDs to filter
    public let account: Account?
    
    /// Nested account structure to hold account-specific filter criteria
    public struct Account: Codable {
        /// Array of account IDs to filter source data
        public let id: [String]?

        /// Public initializer for Account structure
        /// - Parameter id: Array of account identifiers
        ///
        public init(id: [String]) {
            self.id = id
        }
    }
    
    /// Public initializer for SourceFetchFilter
    /// - Parameter account: Account filter criteria
    ///
    public init(account: Account) {
        self.account = account
    }
}
