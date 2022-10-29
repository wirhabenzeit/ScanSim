//
//  ContentView.swift
//  ScanSimUniv
//
//  Created by Dominik Schröder on 16.10.22.
//

import Defaults
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
  @State private var filePicker = false
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
              .toolbar {
                if scanner.outputPdf != nil {
                  ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: scanner.outputPdf!, preview: SharePreview(scanner.fileName()+".pdf", image: scanner.thumbnail()))
                  }
                }
              }
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
            .toolbar(content: {
              ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                  self.filePicker.toggle()
                }) { Text("Select PDF file") }
              }
              if scanner.outputPdf != nil {
                ToolbarItem(placement: .automatic, content: { ShareLink(item: scanner.outputPdf!, preview: SharePreview(scanner.fileName()+".pdf", image: scanner.thumbnail())) })
              }
            })
            .fileImporter(isPresented: $filePicker, allowedContentTypes: [.pdf], allowsMultipleSelection: false, onCompletion: { (res) in
              do {
                let url = try res.get().first!
                Task { try await scanner.load(url: url) }
              } catch { print("Error") }
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
              Button(action: {self.filePicker.toggle()}) { Text("Select PDF File") }
            }
            ToolbarItem(placement: .automatic) {
              Button(action: {
                       scanner.write()
                if appSettings.showResult { NSWorkspace.shared.open(scanner.outputPdf!.location()) }
                     },
                     label: {
                       Image(systemName: "square.and.arrow.up")
                     }).disabled(scanner.outputPdf == nil)
            }
            if scanner.outputPdf != nil {
              ToolbarItem(placement: .automatic, content: { ShareLink(item: scanner.outputPdf!, preview: SharePreview(scanner.fileName()+".pdf", image: scanner.thumbnail())) })
            }
          }
          .fileImporter(isPresented: $filePicker, allowedContentTypes: [.pdf], allowsMultipleSelection: false, onCompletion: { (res) in
            do {
              let url = try res.get().first!
              Task { try await scanner.load(url: url) }
            } catch { print("Error") }
          })
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

extension PDFDocumentURL: Transferable {
  public static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(contentType: .pdf) {
      $0.writeToLocation()
      return SentTransferredFile($0.location())
    } importing: { received in
      return PDFDocumentURL.init(url: received.file)!
    }
  }
  
}

class PDFDocumentURL: PDFDocument {
  public var filename: String = ""
  
  func location() -> URL {
    return Defaults[.appSettings].destinationFolder.url().appendingPathComponent(filename + Defaults[.appSettings].fileNameAddition + ".pdf")
  }
  func writeToLocation() {
    self.write(to: self.location())
  }
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
