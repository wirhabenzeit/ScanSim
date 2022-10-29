//
//  SettingsView.swift
//  ScanSimUniv
//
//  Created by Dominik Schröder on 16.10.22.
//

import CompactSlider
import Defaults
import SwiftUI

struct ScanSettingsView: View {
  @Default(.scanSettings) var settings
  var body: some View {
    List {
      Section(header: Text("Color Settings").font(.headline)) {
        Toggle("Grayscale", isOn: $settings.grayscale).toggleStyle(SwitchToggleStyle())
        Picker("Grayscale contrast", selection: $settings.grayscaleMode) {
          Text("Low").tag(.tonal as GrayscaleMode)
          Text("Medium").tag(.mono as GrayscaleMode)
          Text("High").tag(.noir as GrayscaleMode)
        }.disabled(settings.grayscale == false)
        Picker("Color filter", selection: $settings.colorMode) {
          Text("None").tag(.normal as ColorMode)
          Text("Exaggerated").tag(.chrome as ColorMode)
          Text("Diminished").tag(.fade as ColorMode)
        }.disabled(settings.grayscale)
      }
      Section(header: Text("Quality Settings").font(.headline)) {
        HStack {
          Text("Output Resolution")
          CompactSliderDelayed(value: $settings.dpi, in: 100 ... 450, label: "DPI", valueRenderer: { String(Int($0)) })
        }
        HStack {
          Text("JPEG Quality")
          CompactSliderDelayed(value: $settings.quality, in: 0 ... 100, label: "%", valueRenderer: { String(Int($0)) })
        }
      }
      Section(header: Text("Effect Settings").font(.headline)) {
        HStack {
          Text("Dust   ")
          CompactSliderDelayed(value: $settings.dustAmount, in: 0 ... 1, label: "", valueRenderer: { String(format: "%.2f", $0) })
        }
        HStack {
          Text("Scratches")
          CompactSliderDelayed(value: $settings.scratchAmount, in: 0 ... 1, label: "", valueRenderer: { String(format: "%.2f", $0) })
        }
        Picker("Blur Type", selection: $settings.blurType) {
          Text("None").tag(.none as BlurType)
          Text("Box").tag(.box as BlurType)
          Text("Disc").tag(.disc as BlurType)
          Text("Gaussian").tag(.gaussian as BlurType)
        }
        HStack {
          Text("Blur radius")
          CompactSliderDelayed(value: $settings.blurRadius, in: 0 ... 3, label: "r", valueRenderer: { String(format: "%.2f", $0) }).disabled(settings.blurType == .none)
        }
      }
      Section(header: Text("Rotation Settings").font(.headline)) {
        Picker("Rotation", selection: $settings.rotationType) {
          Text("fixed").tag(.fixed as RotationType)
          Text("random").tag(.random as RotationType)
          Text("none").tag(.none as RotationType)
        }
        HStack {
          Text("Rotation Amount").foregroundColor((settings.rotationType == .none) ? .gray : .black)
          switch settings.rotationType {
          case .fixed:
            CompactSliderDelayed(value: $settings.rotationFixed, in: -3 ... 3, direction: .center, label: "°", valueRenderer: { String(format: "%.1f", $0) })
          case .random:
            CompactSliderDelayed(from: $settings.rotationRange[0], to: $settings.rotationRange[1], in: -3 ... 3, label: "°", valueRenderer: { String(format: "%.1f", $0) })
          case .none:
            CompactSliderDelayed(value: .constant(0.0), in: -3 ... 3, direction: .center, label: "°", valueRenderer: { String(format: "%.1f", $0) }).disabled(true)
          }
        }
      }
    }.frame(minWidth: 300)
  }
}

#if os(macOS)
  struct AppSettingsView: View {
    @Default(.appSettings) var appSettings
    @State private var filePicker = false
    
    var body: some View {
      Form {
        MenuButton(appSettings.destinationFolder.repr()) {
          Button(action: { appSettings.destinationFolder = .temp }) { Text("Temporary Folder") }
          Button(action: { appSettings.destinationFolder = .download }) { Text("Downloads Folder") }
          Button(action: {
            self.filePicker.toggle()
          }) { Text("Other...") }
        }.formLabel(Text("Output Folder"))
        TextField("File name addition", text: $appSettings.fileNameAddition, prompt: Text("custom"))
        Toggle("Open Output File", isOn: $appSettings.showResult)
          .toggleStyle(SwitchToggleStyle())
      }
      .padding(20)
      .frame(minWidth: 400)
      .fileImporter(isPresented: $filePicker, allowedContentTypes: [.folder], allowsMultipleSelection: false, onCompletion: { (res) in
        do {
          let url = try res.get().first!
          appSettings.destinationFolder = .custom(url: url)
        } catch { print("Error") }
      })
    }
  }

  extension HorizontalAlignment {
    private enum ControlAlignment: AlignmentID {
      static func defaultValue(in context: ViewDimensions) -> CGFloat {
        return context[HorizontalAlignment.center]
      }
    }
    static let controlAlignment = HorizontalAlignment(ControlAlignment.self)
  }

  public extension View {
    /// Attaches a label to this view for laying out in a `Form`
    /// - Parameter view: the label view to use
    /// - Returns: an `HStack` with an alignment guide for placing in a form
    func formLabel<V: View>(_ view: V) -> some View {
      HStack {
        view
        self
          .alignmentGuide(.controlAlignment) { $0[.leading] }
      }
      .alignmentGuide(.leading) { $0[.controlAlignment] }
    }
  }
#endif
