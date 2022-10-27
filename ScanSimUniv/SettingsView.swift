//
//  SettingsView.swift
//  ScanSimUniv
//
//  Created by Dominik Schröder on 16.10.22.
//

import CompactSlider
import Defaults
import FilePicker
import SwiftUI

#if os(macOS)
  struct AppSettingsView: View {
    @Default(.appSettings) var appSettings
    var body: some View {
      Form {
        MenuButton(appSettings.destinationFolder.repr()) {
          Button(action: { appSettings.destinationFolder = .temp }) { Text("Temporary Folder") }
          Button(action: { appSettings.destinationFolder = .download }) { Text("Downloads Folder") }
          Button(action: {
            if let url = NSOpenPanel().selectFolder { appSettings.destinationFolder = .custom(url: url) }
          }) { Text("Other...") }
        }.formLabel(Text("Output Folder"))
        TextField("File name addition", text: $appSettings.fileNameAddition, prompt: Text("custom"))
        // Text("Example: /User/username/Desktop/input.pdf\n\t\t􀄍 \(appSettings.destinationFolder.url().path)/input\(appSettings.fileNameAddition).pdf")
        //  .font(.caption)
        //  .foregroundColor(Color.gray)
        Toggle("Open Output File", isOn: $appSettings.showResult)
          .toggleStyle(SwitchToggleStyle())
      }
      .padding(20)
      .frame(width: 400)
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
