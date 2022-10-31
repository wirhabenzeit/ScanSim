//
//  PreviewView.swift
//  ScanSimUniv
//
//  Created by Dominik Schröder on 18.10.22.
//

import Defaults
import PDFKit
import SwiftUI

struct PreviewView: View {
  @ObservedObject var controller: Scanner
  @Binding var filePicker : Bool
  
  var body: some View {
    if controller.outputPdf != nil {
      PDFKitRepresentedView(document: $controller.outputPdf)
      //Image(cpImage: controller.inputImages[0]!).resizable().aspectRatio(contentMode: .fit)
    } else {
      NoDocumentView(controller: controller, filePicker: $filePicker)
    }
  }
}

struct PDFKitRepresentedView: CrossPlatform.ViewRepresentable {
  @Binding var document: PDFDocumentURL?
  #if os(iOS)
    func makeUIView(context _: CrossPlatform.ViewRepresentableContext<PDFKitRepresentedView>) -> PDFKitRepresentedView.UIViewType {
      let pdfView = PDFView()
      pdfView.document = document
      pdfView.displayMode = .singlePageContinuous
      pdfView.autoScales = true
      return pdfView
    }

    func updateUIView(_ uiView: PDFView, context _: CrossPlatform.ViewRepresentableContext<PDFKitRepresentedView>) {
      uiView.document = document
    }
  #else
    func makeNSView(context _: NSViewRepresentableContext<PDFKitRepresentedView>) ->
      PDFKitRepresentedView.NSViewType
    {
      let pdfView = PDFView()
      pdfView.document = document
      pdfView.displayMode = .singlePageContinuous
      pdfView.autoScales = true
      return pdfView
    }

    func updateNSView(_ uiView: PDFView, context _: NSViewRepresentableContext<PDFKitRepresentedView>) {
      uiView.document = document
    }
  #endif
}

struct NoDocumentView: View {
  @ObservedObject var controller: Scanner
  @Binding var filePicker: Bool
  @State private var isTargeted = false
  @State private var presentAlert = false

  var body: some View {
    VStack {
      Button(action: {
        self.filePicker.toggle()
      }) {
        VStack {
          Image(systemName: "doc.richtext").resizable().aspectRatio(contentMode: .fit).frame(width: 150, height: 100)
          Text("Select PDF File").font(.title)
        }.foregroundColor(isTargeted == true ? .blue : Color.gray).padding()
          .onHover { inside in
            #if os(macOS)
            if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            #endif
          }
      }.buttonStyle(.plain)
      Text("or drag and drop it here")
        .fontWeight(.light)
        .foregroundColor(isTargeted == true ? .blue : Color.gray)
    }
    .frame(minWidth: 250, maxWidth: .infinity, minHeight: 200, maxHeight: .infinity)
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(isTargeted == true ? .blue : Color.gray, style: StrokeStyle(lineWidth: 3, dash: [10]))
    )
    .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
      if let provider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) {
        _ = provider.loadObject(ofClass: URL.self) { object, _ in
          if let url = object {
            if url.pathExtension == "pdf" { Task { try await controller.load(url: url) } } else { presentAlert = true }
          }
        }
        return true
      }
      return false
    }
    .padding()
    .alert("Wrong file type", isPresented: $presentAlert, actions: {})
  }
}
