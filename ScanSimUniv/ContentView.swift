//
//  ContentView.swift
//  ScanSimUniv
//
//  Created by Dominik Schröder on 16.10.22.
//

import Defaults
import FilePicker
import PDFKit
import SwiftUI

#if os(iOS)
  struct ShareSheetView: UIViewControllerRepresentable {
    typealias Callback = (_ activityType: UIActivity.ActivityType?, _ completed: Bool, _ returnedItems: [Any]?, _ error: Error?) -> Void
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    let excludedActivityTypes: [UIActivity.ActivityType]? = nil
    let callback: Callback? = nil

    func makeUIViewController(context _: Context) -> UIActivityViewController {
      let controller = UIActivityViewController(
        activityItems: activityItems,
        applicationActivities: applicationActivities
      )
      controller.excludedActivityTypes = excludedActivityTypes
      controller.completionWithItemsHandler = callback
      return controller
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {
      // nothing to do here
    }
  }
#endif

struct ContentView: View {
  @Default(.scanSettings) var settings
  @Default(.appSettings) var appSettings
  @StateObject var scanner = Scanner()
  @State var sheet = false
  var body: some View {
    #if os(iOS)
      if platform == .iOS {
        TabView {
          NavigationView {
            ScanSettingsView()
              .navigationBarTitle("Scan Simulator")
          }
          .tabItem {
            Label("Settings", systemImage: "list.dash")
          }
          .onChange(of: settings) { _ in
            Task { try await scanner.scan() }
          }

          NavigationView {
            PreviewView(controller: scanner)
              .navigationTitle("Scan Preview")
              .navigationBarItems(trailing:
                HStack {
                  Button(action: {
                    scanner.write()
                    sheet = true
                  }, label: {
                    Image(systemName: "square.and.arrow.up")
                  }).disabled(scanner.outputPdf==nil)
                }
                .sheet(isPresented: $sheet, content: {
                  ShareSheetView(activityItems: [scanner.outUrl])
                })
              )
          }
          .tabItem {
            Label("Preview", systemImage: "square.and.pencil")
          }
        }
      } else {
        NavigationView {
          ScanSettingsView()
            .listStyle(SidebarListStyle())
            .onChange(of: settings) { _ in
              Task { try await scanner.scan() }
            }
          PreviewView(controller: scanner)
            .navigationTitle("Scan Simulator")
            .toolbar {
              ToolbarItem(placement: .navigationBarLeading) {
                FilePicker(types: [.pdf], allowMultiple: false) { urls in
                  Task { try await scanner.load(url: urls.first!) }
                }
              label: {
                Text("Select PDF file")
              }
              }
              ToolbarItem(placement: .automatic) {
                Button(action: {
                  scanner.write()
                  sheet = true
                }, label: {
                  Image(systemName: "square.and.arrow.up")
                }).disabled(scanner.outputPdf==nil)
              }
            }
            .sheet(isPresented: $sheet, content: {
              ShareSheetView(activityItems: [scanner.outUrl])
            })
        }
      }
    #else
      NavigationView {
        ScanSettingsView()
          .listStyle(SidebarListStyle())
          .onChange(of: settings) { _ in
            Task { try await scanner.scan() }
          }
        PreviewView(controller: scanner)
          .navigationTitle("Scan Simulator")
          .toolbar {
            ToolbarItem(placement: .automatic) {
              FilePicker(types: [.pdf], allowMultiple: false) { urls in
                Task { try await scanner.load(url: urls.first!) }
              }
            label: {
              Text("Select PDF file")
            }
            }
            ToolbarItem(placement: .automatic) {
              Button(action: {
                       scanner.write()
                if appSettings.showResult { NSWorkspace.shared.open(scanner.outUrl!) }
                     },
                     label: {
                      Image(systemName: "square.and.arrow.up")
              }).disabled(scanner.outputPdf==nil)
            }
          }
      }.toolbar {
        ToolbarItem(placement: .navigation) {
          Button(action: toggleSidebar, label: {
            Image(systemName: "sidebar.leading")
          })
        }
      }
    #endif
  }

  #if os(macOS)
    private func toggleSidebar() {
      NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
    }
  #endif
}


struct SidebarView: View {
  var body: some View {
    NavigationView {
      ScanSettingsView()
        .listStyle(SidebarListStyle())
        .navigationTitle("Scan Settings")
    }
  }
}

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

