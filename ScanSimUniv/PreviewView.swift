//
//  PreviewView.swift
//  ScanSimUniv
//
//  Created by Dominik Schröder on 18.10.22.
//

import SwiftUI
import PDFKit
import Defaults
import FilePicker

struct PreviewView: View {
  @ObservedObject var controller: Scanner
  var body: some View {
    if controller.outputPdf != nil {
      PDFKitRepresentedView(document: $controller.outputPdf )
      .onDrop(of: [.fileURL], isTargeted: .constant(false)) { providers in
        if let provider = providers.first(where: { $0.canLoadObject(ofClass: URL.self) }) {
          _ = provider.loadObject(ofClass: URL.self) { object, _ in
            if let url = object {
              if url.pathExtension == "pdf" { Task { try await controller.load(url: url) } }
            }
          }
          return true
        }
        return false
      }
    } else {
      NoDocumentView(controller: controller)
    }
  }
}

/* struct PreviewView_Previews: PreviewProvider {
     @State var pdfDocument = PDFDocument(url: Bundle.main.url(forResource:"letter", withExtension:"pdf")!)!
     static var previews: some View {
         PreviewView(pdfDocument:$pdfDocument)
     }
 } */


struct PDFKitRepresentedView: CrossPlatform.ViewRepresentable {
  @Binding var document: PDFDocument?
  /*init(_ doc: PDFDocument) {
    self.document = doc
  }*/
  
  #if os(iOS)
  func makeUIView(context: CrossPlatform.ViewRepresentableContext<PDFKitRepresentedView>) -> PDFKitRepresentedView.UIViewType {
    let pdfView = PDFView()
    pdfView.document = self.document
    pdfView.displayMode = .singlePageContinuous
    pdfView.autoScales = true
    return pdfView
  }
  func updateUIView(_ uiView: PDFView, context: CrossPlatform.ViewRepresentableContext<PDFKitRepresentedView>) {
    uiView.document = document
    /*let currentPosition = uiView.currentDestination
    
    if let currentPosition = currentPosition {
      uiView.go(to: currentPosition)
    }*/
  }
  #else
  func makeNSView(context: NSViewRepresentableContext<PDFKitRepresentedView>) ->
  PDFKitRepresentedView.NSViewType {
    let pdfView = PDFView()
    pdfView.document = self.document
    pdfView.displayMode = .singlePageContinuous
    pdfView.autoScales = true
    return pdfView
  }
  func updateNSView(_ uiView: PDFView, context: NSViewRepresentableContext<PDFKitRepresentedView>) {
    //if let currentPosition = uiView.currentDestination {
    //  print("Scrolling to \(currentPosition)")
    //  print("\(uiView.bounds)")
      uiView.document = self.document
      //uiView.go(to: uiView.document!.page(at: 0)!)
    //}
  }
  #endif
}


struct NoDocumentView: View {
  @ObservedObject var controller: Scanner
  @State var isRunning = false
  @State var isTargeted = false
  @State var presentAlert = false
  @Default(.appSettings) var appSettings
  @Default(.scanSettings) var scanSettings
  
  var body: some View {
    VStack {
      Text(isRunning == true ? "􀵋" : "􀉅")
        .font(.system(size: 64))
        .padding()
        .foregroundColor(isTargeted == true ? .blue : Color.gray)
      FilePicker(types: [.pdf], allowMultiple: false) { urls in
        Task { try await controller.load(url: urls.first!) }
      }
    label: {
      Text("Select PDF file")
    }
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
       if url.pathExtension == "pdf" { Task { try await controller.load(url: url) } }
     else { presentAlert = true }
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
