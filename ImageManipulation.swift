//
//  ImageManipulation.swift
//  ScanSimUniv
//
//  Created by Dominik Schröder on 27.10.22.
//

import CoreImage
import Foundation
import PDFKit
import SwiftUI

extension CGImage {
  /// Rotates CGImage in front of a white background
  /// - parameter degrees: Degrees (°) of rotation
  /// - Returns: Rotated image, or nil
  public func rotated(degrees: Double) async -> CGImage? {
    let width = self.width
    let height = self.height
    let bitsPerComponent = self.bitsPerComponent
    let bytesPerRow = self.bytesPerRow
    let colorSpace = self.colorSpace
    let bitmapInfo = self.bitmapInfo
    let radians = CGFloat(degrees * Double.pi / 180)

    if let contextRef = CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace!, bitmapInfo: bitmapInfo.rawValue) {
      contextRef.setFillColor(red: 100.0, green: 100.0, blue: 100.0, alpha: 1.0)
      contextRef.fill([CGRect(x: 0, y: 0, width: width, height: height)])
      contextRef.translateBy(x: CGFloat(width) / 2.0, y: CGFloat(height) / 2.0)
      contextRef.rotate(by: radians)
      contextRef.translateBy(x: -CGFloat(width) / 2.0, y: -CGFloat(height) / 2.0)
      contextRef.draw(self, in: CGRect(x: 0, y: 0, width: width, height: height))

      guard let orientedImage = contextRef.makeImage()
      else { return nil }
      return orientedImage
    } else { return nil }
  }

  /// Adds a scan effect to image
  /// - parameter settings: Instance of `ScanSettings` describing the effect settings
  /// - Returns: Filtered CIImage, or nil
  func asScanned(settings: ScanSettings) async -> CIImage? {
    var ciimage: CIImage?
    print("Rotating")
    if settings.rotationType == .none { ciimage = CIImage(cgImage: self) } else {
      let degrees = settings.rotationType == .random ? Double.random(in: settings.rotationRange[0] ... settings.rotationRange[1]) : settings.rotationFixed
      guard let cgimage = await rotated(degrees: degrees) else { return nil }
      ciimage = CIImage(cgImage: cgimage)
    }
    print("Rotating done -- Adding noise")
    ciimage = ciimage?.addNoise(rvec: [0, 1, 0, 0], gvec: [0, 1, 0, 0], bvec: [0, 1, 0, 0], avec: [0, 0.01 * settings.dustAmount, 0, 0],
                                bias: [0, 0, 0, 0], scale: [2 * settings.dpi / 100, 2 * settings.dpi / 100], blendMode: "CISourceOverCompositing")
    ciimage = ciimage?.addNoise(rvec: [6 / settings.scratchAmount, 0, 0, 0], gvec: [0, 0, 0, 0], bvec: [0, 0, 0, 0], avec: [0, 0, 0, 0],
                                bias: [0, 1, 1, 1], scale: [2 * settings.dpi / 100, 25 * settings.dpi / 100], blendMode: "CIMultiplyCompositing")
    print("Noise added -- Applying colour filter")
    var photoEffect: String?
    if settings.grayscale {
      photoEffect = settings.grayscaleMode.rawValue.capitalized
    } else if settings.colorMode != .normal {
      photoEffect = settings.colorMode.rawValue.capitalized
    }
    if let photoEffect = photoEffect {
      let photoFilter = CIFilter(name: "CIPhotoEffect" + photoEffect, parameters: ["inputImage": ciimage!])
      ciimage = photoFilter?.outputImage
    }
    print("colour filter applied -- now blur")
    if settings.blurType != .none {
      ciimage = CIFilter(name: "CI" + settings.blurType.rawValue.capitalized + "Blur", parameters: ["inputImage": ciimage, "inputRadius": settings.blurRadius * settings.dpi / 100])!.outputImage!
    }
    return ciimage
  }
}

extension CIImage {
  /// Create a CGImage version of this image
  ///
  /// - Returns: Converted image, or nil
  func asCGImage() async -> CGImage? {
    print("Converting CI to CG Image")
    let context = CIContext(options: nil)
    guard let cgImage = context.createCGImage(self, from: extent)
    else { return nil }
    print("Ci -> CG: Success")
    return cgImage
  }

  /// Overlays noise over the image
  ///
  /// - parameter rvec: red component of `CiColorMatrix`
  /// - parameter gvec: green component of `CiColorMatrix`
  /// - parameter bvec: blue component of `CiColorMatrix`
  /// - parameter gvec: alpha (opacity) component of `CiColorMatrix`
  /// - parameter scale: `[sx,sy]` with `sx,sy` describing the stretch factor of the noise in horizontal and vertical direction
  /// - parameter blendMode: `CICategoryCompositeOperation` effect name
  public func addNoise(rvec: [Double], gvec: [Double], bvec: [Double], avec: [Double], bias: [Double], scale: [Double], blendMode: String) -> CIImage? {
    let noiseImage: CIImage = CIFilter(name: "CIRandomGenerator")!.outputImage!
    let verticalScale = CGAffineTransform(scaleX: scale[0], y: scale[1])
    let transformedNoise = noiseImage.transformed(by: verticalScale)
    guard let filter = CIFilter(name: "CIColorMatrix",
                                parameters:
                                [
                                  kCIInputImageKey: transformedNoise,
                                  "inputRVector": CIVector(x: rvec[0], y: rvec[1], z: rvec[2], w: rvec[3]),
                                  "inputGVector": CIVector(x: gvec[0], y: gvec[1], z: gvec[2], w: gvec[3]),
                                  "inputBVector": CIVector(x: bvec[0], y: bvec[1], z: bvec[2], w: bvec[3]),
                                  "inputAVector": CIVector(x: avec[0], y: avec[1], z: avec[2], w: avec[3]),
                                  "inputBiasVector": CIVector(x: bias[0], y: bias[1], z: bias[2], w: bias[3]),
                                ]),
      let filteredNoiseImage = filter.outputImage,
      let bnwNoiseImage = CIFilter(name: "CIMinimumComponent", parameters: [kCIInputImageKey: filteredNoiseImage])!.outputImage,
      let speckCompositor = CIFilter(name: blendMode,
                                     parameters:
                                     [
                                       kCIInputImageKey: bnwNoiseImage,
                                       kCIInputBackgroundImageKey: self,
                                     ]),
      let speckledImage = speckCompositor.outputImage
    else {
      return nil
    }
    return speckledImage.cropped(to: extent)
  }
}

extension CrossPlatform.Image {
  func asCIImage() async -> CIImage? {
    print("converting UI/NS to CI Image")
    #if os(iOS)
      guard let ciiImg = CIImage(image: self)
      else { return nil }
    #else
      guard let imageData = tiffRepresentation,
            let ciiImg = CIImage(data: imageData)
      else { return nil }
    #endif
    return ciiImg
  }

  func asCGImage() async -> CGImage? {
    return await asCIImage()?.asCGImage()
  }

  func asScanned(settings: ScanSettings) async -> CrossPlatform.Image? {
    let cicontext = CIContext()
    let options = [
      kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: settings.quality / 100,
    ]
    guard let ciimage = await asCGImage()?.asScanned(settings: settings),
          let jpegimage = cicontext.jpegRepresentation(of: ciimage, colorSpace: CGColorSpace(name: "kCGColorSpaceDeviceRGB" as CFString)!, options: options)
    else { return nil }
    print("JPEG export done")
    return CrossPlatform.Image(data: jpegimage)
  }
}

extension PDFDocument {
  func image(dpi: Double, page: Int) async -> CrossPlatform.Image? {
    print("Trying to render page \(page).")
    guard let pdfPage = self.page(at: page)
    else { print("Page \(page) returned nil"); return nil }
    let pageRect = pdfPage.bounds(for: .mediaBox)
    let pixels = Int(Double(pageRect.height) * dpi / 72.0)
    let img = pdfPage.thumbnail(of: CGSize(width: pixels, height: pixels), for: PDFDisplayBox.trimBox)
    print("Rendered page \(page).")
    return img
  }
}
