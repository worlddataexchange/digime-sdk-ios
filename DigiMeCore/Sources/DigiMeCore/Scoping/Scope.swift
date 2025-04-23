//
//  Scope.swift
//  DigiMeCore
//
//  Created on 06/06/2021.
//  Copyright © 2021 digi.me Limited. All rights reserved.
//

import Foundation

/// Scope used to limit service-based data retrieval to specified services and a specified time ranges
public struct Scope: Codable {
    public let serviceGroups: [ServiceGroupType]?
    public let timeRanges: [TimeRange]?
    public let sourceFetch: Bool?
    public let sourceFetchFilter: SourceFetchFilter?
    
    /// Limits data retrieval to specified services or service groups and optionally to specified time range.
    /// If both service groups and time ranges are specified, then response will be limited to data matching both limits
    ///
    /// - Parameters:
    ///   - serviceGroups: Service groups (and associated services) to limit data request to
    ///   - timeRanges: Optional time range to limit data retrieval to
    ///   - sourceFetch: If set to false user will be able to see only existing data, without refreshing the library. Default value is true.
    ///   - sourceFetchFilter: Trigger account data sync only for accounts matching session scope and specified filter.
    public init(serviceGroups: [ServiceGroupType]? = nil, timeRanges: [TimeRange]? = nil, sourceFetch: Bool = true, sourceFetchFilter: SourceFetchFilter? = nil) {
        self.serviceGroups = serviceGroups
        self.timeRanges = timeRanges
        self.sourceFetch = sourceFetch
        self.sourceFetchFilter = sourceFetchFilter
    }
}
