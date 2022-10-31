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
    GeometryReader { geometry in
      List {
        Section(header: Text("Color settings").font(.headline)) {
          Toggle("Grayscale", isOn: $settings.grayscale).toggleStyle(SwitchToggleStyle())
          Picker("Grayscale contrast", selection: $settings.grayscaleMode) {
            Text("Low").tag(.tonal as GrayscaleMode)
            Text("Medium").tag(.mono as GrayscaleMode)
            Text("High").tag(.noir as GrayscaleMode)
          }.disabled(settings.grayscale == false).buttonStyle(BorderlessButtonStyle())
          Picker("Color filter", selection: $settings.colorMode) {
            Text("None").tag(.normal as ColorMode)
            Text("Exaggerated").tag(.chrome as ColorMode)
            Text("Diminished").tag(.fade as ColorMode)
          }.disabled(settings.grayscale).buttonStyle(BorderlessButtonStyle())
        }
        Section(header: Text("Quality settings").font(.headline)) {
          LabeledContent("Output resolution") {
            CompactSliderDelayed(value: $settings.dpi, in: 100 ... 450, label: "DPI", valueRenderer: { String(Int($0)) }).frame(width: geometry.size.width - 170)
          }
          LabeledContent("JPEG quality") {
            CompactSliderDelayed(value: $settings.quality, in: 0 ... 100, label: "%", valueRenderer: { String(Int($0)) }).frame(width: geometry.size.width - 170)
          }
        }
        Section(header: Text("Effect settings").font(.headline)) {
          LabeledContent("Dust") {
            CompactSliderDelayed(value: $settings.dustAmount, in: 0 ... 1, label: "", valueRenderer: { String(format: "%.2f", $0) }).frame(width: geometry.size.width - 170)
          }
          LabeledContent("Scratches") {
            CompactSliderDelayed(value: $settings.scratchAmount, in: 0 ... 1, label: "", valueRenderer: { String(format: "%.2f", $0) }).frame(width: geometry.size.width - 170)
          }
          Picker("Blur type", selection: $settings.blurType) {
              Text("None").tag(.none as BlurType)
              Text("Box").tag(.box as BlurType)
              Text("Disc").tag(.disc as BlurType)
              Text("Gaussian").tag(.gaussian as BlurType)
          }.buttonStyle(BorderlessButtonStyle())
          LabeledContent("Blur radius") {
            CompactSliderDelayed(value: $settings.blurRadius, in: 0 ... 3, label: "r", valueRenderer: {
              String(format: "%.2f", $0)
            }).disabled(settings.blurType == .none).frame(width: geometry.size.width - 170)
          }
        }
        Section(header: Text("Rotation settings").font(.headline)) {
          Picker("Type", selection: $settings.rotationType) {
            Text("Fixed").tag(.fixed as RotationType)
            Text("Random").tag(.random as RotationType)
            Text("None").tag(.none as RotationType)
          }.buttonStyle(BorderlessButtonStyle())
          LabeledContent("Amount") {
            switch settings.rotationType {
            case .fixed:
              CompactSliderDelayed(value: $settings.rotationFixed, in: -3 ... 3, direction: .center, label: "°", valueRenderer: { String(format: "%.1f", $0) }).frame(width: geometry.size.width - 170)
            case .random:
              CompactSliderDelayed(from: $settings.rotationRange[0], to: $settings.rotationRange[1], in: -3 ... 3, label: "°", valueRenderer: {
                String(format: "%.1f", $0)
              }).frame(width: geometry.size.width - 170)
            case .none:
              CompactSliderDelayed(value: .constant(0.0), in: -3 ... 3, direction: .center, label: "°", valueRenderer: {
                String(format: "%.1f", $0)
              }).disabled(true).frame(width: geometry.size.width - 170)
            }
          }
        }
      }
    }
  }
}

struct ScanSettings_Previews:
  PreviewProvider {
  static var previews: some View {
    ScanSettingsView().frame(width:300,height:500)
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
