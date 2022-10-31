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
import UniformTypeIdentifiers

enum ScanSimError : Error {
  case pdfImportError
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

extension Image {
  init(cpImage: CrossPlatform.Image) {
#if os(iOS)
    self.init(uiImage: cpImage)
#elseif os(OSX)
    self.init(nsImage: cpImage)
#endif
  }
}

@main
struct ScanSimUnivApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
    }.commands {
      SidebarCommands() // 1
    }
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
  @Published var outputPdf: PDFDocumentURL?
  @Published var inputImages: [CrossPlatform.Image?] = []
  private var _fileName: String = ""
  var inputPdf: PDFDocument?
  private var pageCount: Int?
  
  private var dpi: Double = Defaults[.scanSettings].dpi

  func fileName() -> String {
    return outputPdf!.filename + appSettings.fileNameAddition
  }
  
  func thumbnail() -> Image {
    let pdfPage = outputPdf!.page(at: 0)!
    let pageRect = pdfPage.bounds(for: .mediaBox)
    let pixels = Int(Double(pageRect.height) * settings.dpi / 72.0)
    let img = pdfPage.thumbnail(of: CGSize(width: pixels, height: pixels), for: PDFDisplayBox.mediaBox)
    return Image(cpImage: img)
  }
  
  func load(url: URL) async throws {
    if url.startAccessingSecurityScopedResource() {
      guard let pdfDocument = PDFDocument(url: url),
            let data = pdfDocument.dataRepresentation(),
            let inputPdf = PDFDocument(data: data),
            let outputPdf = PDFDocumentURL(data: data)
      else { throw ScanSimError.pdfImportError }
      url.stopAccessingSecurityScopedResource()
      self.inputPdf = inputPdf
      self.outputPdf = outputPdf
      pageCount = inputPdf.pageCount
      outputPdf.filename = url.deletingPathExtension().lastPathComponent
      print("PDF loaded")
      await render()
      print("PDF rendered")
      try await scan()
    }   
  }

  func render() async {
    if let pageCount = pageCount {
      var tempInputImages: [CrossPlatform.Image?] = Array(repeating: nil, count: pageCount)
      await withTaskGroup(of: (Int, CrossPlatform.Image?).self) { group in
        for page in 0 ..< pageCount {
          group.addTask {
            await (page, self.inputPdf!.image(dpi: self.settings.dpi, page: page))
          }
        }
        for await (page, image) in group {
          tempInputImages[page] = image
          print("Page \(page) rendered of size \(image?.size)")
        }
      }
      inputImages = tempInputImages
    }
  }

  func scan() async throws {
    if settings.dpi != dpi {
      await render()
      dpi = settings.dpi
    }
    if let pageCount = pageCount {
      await withTaskGroup(of: (Int, PDFPage?).self) { group in
        for page in 0 ... pageCount - 1 {
          group.addTask {
            guard let scannedImg = await self.inputImages[page]?.asScanned(settings: self.settings)
            else { return (page, nil) }
            guard let cgImage = await scannedImg.asCGImage() else { return (page, nil) }

            #if os(macOS)
              let image = NSImage(cgImage: cgImage, size: scannedImg.size)
            #else
              let image = UIImage(cgImage: cgImage, scale: scannedImg.scale, orientation: .up)
            #endif

            guard let scannedPage = await PDFPage(image: scannedImg, options:
                    [.mediaBox: self.inputPdf!.page(at: page)!.bounds(for: .mediaBox),
                      .compressionQuality: self.settings.quality/100,
                      .upscaleIfSmaller: true ]) else { return (page, nil) }
            //scannedPage.setBounds(CGRect(x: 0, y: 0, width: 595.2, height: 841.8), for: .mediaBox)
            //await scannedPage.setBounds(self.inputPdf!.page(at: page)!.bounds(for: .mediaBox), for: .mediaBox)
            //await scannedPage.setBounds(self.inputPdf!.page(at: page)!.bounds(for: .cropBox), for: .cropBox)
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
    outputPdf?.writeToLocation()
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
