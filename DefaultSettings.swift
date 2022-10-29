//
//  DefaultSettings.swift
//  ScanSimUniv
//
//  Created by Dominik Schröder on 27.10.22.
//

import Defaults
import Foundation

let defaultScanSettings = ScanSettings(dpi: 200,
                                       rotationType: .fixed,
                                       rotationFixed: 1.5,
                                       rotationRange: [0, 1.5],
                                       quality: 20.0,
                                       grayscale: true,
                                       grayscaleMode: .noir,
                                       colorMode: .normal,
                                       scratchAmount: 0.3,
                                       dustAmount: 0.5,
                                       blurType: .none,
                                       blurRadius: 1)

let defaultAppSettings = AppSettings(showResult: true,
                                     destinationFolder: .temp,
                                     fileNameAddition: "")

extension Defaults.Keys {
  static let scanSettings = Key<ScanSettings>("scanSettings", default: defaultScanSettings)
  static let appSettings = Key<AppSettings>("appSettings", default: defaultAppSettings)
}

struct ScanSettings: Codable, Equatable, Defaults.Serializable {
  var dpi: Double
  var rotationType: RotationType
  var rotationFixed: Double
  var rotationRange: [Double]
  var quality: Double
  var grayscale: Bool
  var grayscaleMode: GrayscaleMode
  var colorMode: ColorMode
  var scratchAmount: Double
  var dustAmount: Double
  var blurType: BlurType
  var blurRadius: Double
}

struct AppSettings: Codable, Defaults.Serializable {
  var showResult: Bool
  var destinationFolder: DestinationFolder
  var fileNameAddition: String
}

enum GrayscaleMode: String, Codable {
  case noir
  case tonal
  case mono
}

enum ColorMode: String, Codable {
  case instant
  case process
  case chrome
  case normal
  case fade
  case transfer
}

enum RotationType: String, Codable {
  case random
  case fixed
  case none
}

enum BlurType: String, Codable {
  case gaussian
  case box
  case disc
  case none
}

enum DestinationFolder: Codable, Defaults.Serializable {
  case temp
  case download
  case custom(url: URL)

  func repr() -> String {
    switch self {
    case .temp: return "Temporary Folder"
    case .download: return "Downloads Folder"
    case let .custom(url): return "􀈖 " + url.path
    }
  }

  func url() -> URL {
    switch self {
    case .download: return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
    case .temp: return URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    case let .custom(url): return url
    }
  }
}
