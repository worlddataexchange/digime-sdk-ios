//
//  CallbackError.swift
//  DigiMeCore
//
//  Created on 11/06/2021.
//  Copyright © 2021 digi.me Limited. All rights reserved.
//

import Foundation

public enum CallbackError: Error {
    case unexpectedCallbackAction
    case invalidCallbackParameters
}
