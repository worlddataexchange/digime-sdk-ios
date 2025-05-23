//
//  MimeType.swift
//  DigiMeCore
//
//  Created on 24/06/2021.
//  Copyright © 2021 digi.me Limited. All rights reserved.
//

import Foundation

public enum MimeType: String, CaseIterable, Codable {
    case applicationJson = "application/json"
    case applicationOctetStream = "application/octet-stream"
	case applicationPdf  = "application/pdf"
	
    case imageJpg = "image/jpg"
    case imageJpeg = "image/jpeg"
    case imageTiff = "image/tiff"
    case imagePng = "image/png"
    case imageGif = "image/gif"
    case imageBmp = "image/bmp"
    
    case textPlain = "text/plain"
    case textJson = "text/json"
}
