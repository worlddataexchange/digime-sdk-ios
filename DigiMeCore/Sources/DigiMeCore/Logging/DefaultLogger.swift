//
//  DefaultLogger.swift
//  DigiMeCore
//
//  Created on 30/07/2021.
//  Copyright © 2021 digi.me Limited. All rights reserved.
//

import Foundation

class DefaultLogger: Logging {
    func log(level: LogLevel, message: String, file: String, function: String, line: UInt, metadata: Any? = nil) {
        NSLog("[DigiMeSDK] [\(level.rawValue.uppercased())] \(message)")
    }
}
