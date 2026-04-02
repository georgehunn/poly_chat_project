import Foundation
import PDFKit
import UniformTypeIdentifiers

@MainActor
class PDFDocumentService {
    static let shared = PDFDocumentService()

    private let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB

    enum PDFError: Error {
        case fileNotFound
        case fileTooLarge
        case invalidFile
        case extractionFailed

        var localizedDescription: String {
            switch self {
            case .fileNotFound:
                return "File not found"
            case .fileTooLarge:
                return "File size exceeds 50MB limit"
            case .invalidFile:
                return "Invalid PDF file"
            case .extractionFailed:
                return "Failed to extract text from PDF"
            }
        }
    }

    /// Extract text from a PDF file
    /// - Parameter fileURL: The URL of the PDF file
    /// - Returns: Extracted text content
    /// - Throws: PDFError
    func extractText(from fileURL: URL) async throws -> String {
        // Check file size first
        let fileSize = try FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64 ?? 0
        if fileSize > maxFileSize {
            throw PDFError.fileTooLarge
        }

        // Verify it's a PDF file using UniformTypeIdentifiers
        let fileExtension = fileURL.pathExtension.lowercased()
        let isPDF = fileExtension == "pdf"

        if !isPDF {
            // Try to open anyway - sometimes file extension is wrong
            guard let doc = PDFDocument(url: fileURL) else {
                throw PDFError.invalidFile
            }
            // If we can get a document, it's probably fine
            _ = doc
        }

        // Extract text from PDF
        guard let document = PDFDocument(url: fileURL) else {
            throw PDFError.invalidFile
        }

        // Get text from all pages
        var extractedText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i),
               let text = page.string {
                extractedText += text
                extractedText += "\n\n" // Add spacing between pages
            }
        }

        if extractedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw PDFError.extractionFailed
        }

        return extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Process a PDF file and create a DocumentAttachment
    /// - Parameter fileURL: The URL of the PDF file
    /// - Returns: DocumentAttachment with filename and extracted text
    /// - Throws: PDFError
    func processPDF(from fileURL: URL) async throws -> DocumentAttachment {
        let filename = fileURL.lastPathComponent
        let textContent = try await extractText(from: fileURL)

        return DocumentAttachment(filename: filename, textContent: textContent)
    }

    /// Clean up old PDF files that are no longer needed
    /// Files older than 24 hours are deleted
    func cleanupOldPDFFiles() async {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

        let oneDayAgo = Date().addingTimeInterval(-24 * 60 * 60)

        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsDir, includingPropertiesForKeys: [.contentModificationDateKey], options: [])
            for fileURL in files {
                if fileURL.pathExtension == "pdf" {
                    let attrs = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
                    if let modificationDate = attrs.contentModificationDate, modificationDate < oneDayAgo {
                        print("Removing old PDF: \(fileURL.lastPathComponent)")
                        try FileManager.default.removeItem(at: fileURL)
                    }
                }
            }
        } catch {
            print("Error cleaning up old PDF files: \(error)")
        }
    }
}
