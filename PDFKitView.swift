import SwiftUI
import PDFKit

public struct PDFKitRepresentable: UIViewRepresentable {
    let url: URL
    
    public init(url: URL) {
        self.url = url
    }
    
    public func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(url: url)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    public func updateUIView(_ uiView: PDFView, context: Context) {
        // We can reload if needed, but normally static
    }
}

public struct PDFKitView: View {
    let fileURL: URL
    let title: String
    
    @Environment(\.dismiss) private var dismiss
    
    public init(fileURL: URL, title: String) {
        self.fileURL = fileURL
        self.title = title
    }
    
    public var body: some View {
        NavigationStack {
            PDFKitRepresentable(url: fileURL)
                .background(Color(.systemGroupedBackground))
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ShareLink(item: fileURL) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}
