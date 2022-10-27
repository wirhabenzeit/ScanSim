//
//  ScanSimUnivApp.swift
//  ScanSimUniv
//
//  Created by Dominik Schröder on 16.10.22.
//

import CompactSlider
import Defaults
import Foundation
import PDFKit
import SwiftUI


enum ScanError: Error {
  case imageConversion
  case pdfError
}

enum CrossPlatform {
  #if os(macOS)
    typealias Image = NSImage
    typealias ViewRepresentable = NSViewRepresentable
    typealias ViewRepresentableContext = NSViewRepresentableContext
  #elseif os(iOS)
    typealias Image = UIImage
    typealias ViewRepresentable = UIViewRepresentable
    typealias ViewRepresentableContext = UIViewRepresentableContext
  #endif
  
}

enum Platform {
  case macOS, iOS, iPadOS
}

#if os(macOS)
  let platform: Platform = .macOS
#else
  let platform: Platform = (UIDevice.current.userInterfaceIdiom == .pad) ? .iPadOS : .iOS
#endif

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

@main
struct ScanSimUnivApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }.commands {
      SidebarCommands() // 1
    }
    /*
     WindowGroup("Preview Window") {
         PreviewView()
     }.handlesExternalEvents(matching: Set(arrayLiteral: "PreviewWindow"))*/
    #if os(macOS)
      Settings {
        AppSettingsView()
      }
    #endif
  }
}

class Scanner: ObservableObject {
  @Default(.scanSettings) var settings
  @Default(.appSettings) var appSettings
  @Published var outputPdf: PDFDocument?
  private var inputPdf: PDFDocument?
  private var pageCount: Int?
  private var inputImages: [CrossPlatform.Image?] = []
  private var outUrl: URL?
  private var dpi: Double = Defaults[.scanSettings].dpi
  private var fileName: String = ""

  func load(url: URL) async throws {
    inputPdf = PDFDocument(url: url)
    outputPdf = PDFDocument(data: inputPdf!.dataRepresentation()!)
    /*if inputPdf != nil {
      let output2 = PdfActor(inputPdf!)
      print("Actor loaded",output2,inputPdf)
      output = output2
      print(output)
    }*/
    pageCount = inputPdf?.pageCount
    fileName = url.deletingPathExtension().lastPathComponent
    outUrl = appSettings.destinationFolder.url().appendingPathComponent(fileName + appSettings.fileNameAddition + ".pdf")
    print("PDF loaded")
    await render()
    print("PDF rendered")
    try await scan()
    // firstPageImg = inputPdf?.asScannedImage(settings: settings)
  }

  func render() async {
    if let pageCount = pageCount {
      var tempInputImages: [CrossPlatform.Image?] = Array(repeating: nil, count: pageCount)
      await withTaskGroup(of: (Int, CrossPlatform.Image?).self) { group in
        for page in 0..<pageCount {
          group.addTask {
            return await (page, self.inputPdf!.png(dpi: self.settings.dpi, page: page))
          }
        }
        for await (page, image) in group {
          tempInputImages[page] = image
          print("Page \(page) rendered of size \(image?.size)")
        }
      }
      self.inputImages = tempInputImages
    }
  }

  func scan() async throws {
    if settings.dpi != self.dpi {
      await self.render()
      self.dpi = settings.dpi
    }
    if let pageCount = pageCount {
      await withTaskGroup(of: (Int, PDFPage?).self) { group in
        for page in 0...pageCount-1 {
          group.addTask {
            guard let scannedImg = await self.inputImages[page]?.asScanned(settings: self.settings)
            else { return (page, nil) }
            guard let cgImage = await scannedImg.asCGImage() else { return (page, nil) }

            #if os(macOS)
            let image = NSImage(cgImage: cgImage, size: scannedImg.size )
            #else
            let image = UIImage(cgImage: cgImage, scale: scannedImg.scale, orientation: .up)
            #endif

            guard let scannedPage = PDFPage(image: image) else { return (page, nil) }
            await scannedPage.setBounds(self.inputPdf!.page(at: page)!.bounds(for: .mediaBox), for: .mediaBox)
            print("PDF page created")
            return (page, scannedPage)
          }
        }
        for await (pageNumber, page) in group {
          print("trying to write page \(pageNumber)")
          guard let page = page else { return }
          outputPdf?.removePage(at: pageNumber)
          outputPdf?.insert(page, at: pageNumber)
        }
      }
      print("PDF written")
    }
  }

  func write() {
    outputPdf?.write(to: self.outUrl!)
  }

  /*
  func renderFirstPage() {
    firstPage = inputPdf?.png(dpi: settings.dpi, page: 0)
    dpi = settings.dpi
  }
   */

  /*func scanFirstPage() {
    if firstPage != nil {
      DispatchQueue.global(qos: .default).async {
        if self.dpi != self.settings.dpi {
          print("DPI changed!")
          self.renderFirstPage()
        }
        self.firstPageImgCache = CrossPlatform.Image(data: self.firstPage!.asScanned(settings: self.settings)!)
        DispatchQueue.main.async {
          self.firstPageImg = self.firstPageImgCache
          print("Image rendered")
        }
      }
    }
  }*/

  /*func writeDocument() {
    let outUrl = appSettings.destinationFolder.url().appendingPathComponent(fileName + appSettings.fileNameAddition + ".pdf")
    if let outputPdf = inputPdf?.asScanned(settings: settings) {
      DispatchQueue.global(qos: .userInteractive).async {
        print("Rendering PDF")
        outputPdf.write(to: self.outUrl)
        DispatchQueue.main.async {
          print("Success!")
          #if os(macOS)
            if self.appSettings.showResult {
              NSWorkspace.shared.open(self.outUrl)
            }
          #endif
        }
      }
    }
  }*/
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

#if os(macOS)
  extension NSOpenPanel {
    var selectPDF: URL? {
      title = "Select PDF"
      allowsMultipleSelection = false
      canChooseDirectories = false
      canChooseFiles = true
      canCreateDirectories = false
      allowedContentTypes = [.pdf]
      return runModal() == .OK ? urls.first : nil
    }

    var selectFolder: URL? {
      title = "Select Folder"
      allowsMultipleSelection = false
      canChooseDirectories = true
      canCreateDirectories = true
      canChooseFiles = false
      return runModal() == .OK ? urls.first : nil
    }
  }
#endif

extension CGImage {
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

  public func addNoise(rvec: [Double], gvec: [Double], bvec: [Double], avec: [Double], bias: [Double], scale: [Double], blendMode: String) -> CIImage? {
    let noiseImage: CIImage = CIFilter(name: "CIRandomGenerator")!.outputImage!
    let verticalScale = CGAffineTransform(scaleX: scale[0], y: scale[1])
    let transformedNoise = noiseImage.transformed(by: verticalScale)
    guard
      let filter = CIFilter(name: "CIColorMatrix",
                            parameters:
                            [
                              kCIInputImageKey: transformedNoise,
                              "inputRVector": CIVector(x: rvec[0], y: rvec[1], z: rvec[2], w: rvec[3]),
                              "inputGVector": CIVector(x: gvec[0], y: gvec[1], z: gvec[2], w: gvec[3]),
                              "inputBVector": CIVector(x: bvec[0], y: bvec[1], z: bvec[2], w: bvec[3]),
                              "inputAVector": CIVector(x: avec[0], y: avec[1], z: avec[2], w: avec[3]),
                              "inputBiasVector": CIVector(x: bias[0], y: bias[1], z: bias[2], w: bias[3])
                            ]),
      let filteredNoiseImage = filter.outputImage
    else {
      return nil
    }
    guard let bnwNoiseImage = CIFilter(name: "CIMinimumComponent", parameters: [kCIInputImageKey: filteredNoiseImage])!.outputImage
    else { return nil }
    guard
      let speckCompositor = CIFilter(name: blendMode,
                                     parameters:
                                     [
                                       kCIInputImageKey: bnwNoiseImage,
                                       kCIInputBackgroundImageKey: self
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
      guard let imageData = self.tiffRepresentation,
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
      kCGImageDestinationLossyCompressionQuality as CIImageRepresentationOption: settings.quality / 100
    ]
    guard let ciimage = await self.asCGImage()?.asScanned(settings: settings),
          let jpegimage = cicontext.jpegRepresentation(of: ciimage, colorSpace: CGColorSpace(name: "kCGColorSpaceDeviceRGB" as CFString)!, options: options)
    else { return nil }
    print("JPEG export done")
    return CrossPlatform.Image(data: jpegimage)
  }
}

// #endif

extension PDFDocument {
  /*func asScanned(settings: ScanSettings) async -> PDFDocument? {
    var pagesFiltered: [PDFPage?] = Array(repeating: nil, count: self.pageCount)
    pagesFiltered.withUnsafeMutableBufferPointer { buffer in
      DispatchQueue.concurrentPerform(iterations: self.pageCount) { pageNumber in
        let pdfPage = self.page(at: pageNumber)!
        let pageRect = pdfPage.bounds(for: .mediaBox)
        let pixels = Int(Double(pageRect.height) * settings.dpi / 72.0)
        var nsuiimage = pdfPage.thumbnail(of: CGSize(width: pixels, height: pixels), for: PDFDisplayBox.trimBox)
        nsuiimage = await CrossPlatform.Image(data: nsuiimage.asScanned(settings: settings)!)!
        var page = PDFPage(image: nsuiimage)
        page!.setBounds(CGRect(x: 0, y: 0, width: nsuiimage.size.width, height: nsuiimage.size.height), for: .mediaBox)
        buffer[pageNumber] = page
      }
    }
    var pdfFiltered: PDFDocument?
    var pageCount = 0
    for page in pagesFiltered {
      if page != nil {
        if pageCount == 0 {
          let pageData: Data = page!.dataRepresentation!
          pdfFiltered = PDFDocument(data: pageData)!
          pageCount += 1
        } else {
          pdfFiltered!.insert(page!, at: pageCount)
          pageCount += 1
        }
      }
    }
    return pdfFiltered
  }
  */
  func png(dpi: Double, page: Int) async -> CrossPlatform.Image? {
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

extension Image {
  init(cpImage: CrossPlatform.Image) {
    #if os(iOS)
      self.init(uiImage: cpImage)
    #elseif os(OSX)
      self.init(nsImage: cpImage)
    #endif
  }
}

struct CompactSliderDelayed<Value: BinaryFloatingPoint>: View {
  @State var state: CompactSliderState
  @State private var value: Value
  @State private var from: Value
  @State private var to: Value
  let direction: CompactSliderDirection = .leading
  var extValue: Binding<Value>
  var extFrom: Binding<Value>
  var extTo: Binding<Value>
  let bounds: ClosedRange<Value>
  let label: String
  let step: Value
  let valueRenderer: (Value) -> String
  let range: Bool

  public init(
    value: Binding<Value>,
    in bounds: ClosedRange<Value> = 0 ... 1,
    step: Value = 0,
    direction _: CompactSliderDirection = .leading,
    label: String = "",
    valueRenderer: @escaping (Value) -> String = { _ in "" }
  ) {
    _state = State(initialValue: .zero)
    _value = State(initialValue: value.wrappedValue)
    _from = State(initialValue: value.wrappedValue)
    _to = State(initialValue: value.wrappedValue)
    self.bounds = bounds
    extValue = value
    extFrom = .constant(0 as Value)
    extTo = .constant(0 as Value)
    self.valueRenderer = valueRenderer
    self.label = label
    self.step = step
    range = false
  }

  public init(
    from: Binding<Value>,
    to: Binding<Value>,
    in bounds: ClosedRange<Value> = 0 ... 1,
    step: Value = 0,
    direction _: CompactSliderDirection = .leading,
    label: String = "",
    valueRenderer: @escaping (Value) -> String = { _ in "" }
  ) {
    _state = State(initialValue: .zero)
    _value = State(initialValue: from.wrappedValue)
    _from = State(initialValue: from.wrappedValue)
    _to = State(initialValue: to.wrappedValue)
    self.bounds = bounds
    extValue = .constant(0 as Value)
    extFrom = from
    extTo = to
    self.valueRenderer = valueRenderer
    self.label = label
    self.step = step
    range = true
  }

  var body: some View {
    if range == false {
      CompactSlider(value: $value, in: bounds, step: step, direction: direction, state: $state, valueLabel: {
        Text(label)
        Spacer()
        Text(valueRenderer(value))
      }).onChange(of: state.isDragging == true, perform: { _ in
        extValue.wrappedValue = value
      })
    } else {
      CompactSlider(from: $from, to: $to, in: bounds, step: step, state: $state, valueLabel: {
        Text(label)
        Spacer()
        Text(valueRenderer(from) + " - " + valueRenderer(to))
      }).onChange(of: state.isDragging == true, perform: { _ in
        extFrom.wrappedValue = from
        extTo.wrappedValue = to
      })
    }
  }
}
