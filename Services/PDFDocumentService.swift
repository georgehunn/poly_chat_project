import Foundation
import PDFKit
import UIKit

class PDFDocumentService: ObservableObject {
    static let shared = PDFDocumentService()

    private let maxFileSize: Int64 = 50 * 1024 * 1024 // 50MB limit
private let thumbnailSize = CGSize(width: 120, height: 160) // Aspect ratio similar to standard PDF

    private init() {}

    /// Generate a thumbnail image from the first page of a PDF
    /// - Parameter url: The URL of the PDF file
    /// - Returns: A UIImage representing the thumbnail, or nil if generation fails
    func generatePDFThumbnail(from url: URL) -> UIImage? {
        do {
            // Check if we have permission to access the file
            guard url.startAccessingSecurityScopedResource() else {
                return nil
            }
            defer { url.stopAccessingSecurityScopedResource() }

            // Load the PDF document
            guard let document = PDFDocument(url: url) else {
                return nil
            }

            // Get the first page
            guard let page = document.page(at: 0) else {
                return nil
            }

            // Create a thumbnail image
            let pageBounds = page.bounds(for: .mediaBox)

            // Create the thumbnail image with a reasonable size
            let thumbnailSize = CGSize(width: 80, height: 100) // Fixed size for better performance

            return page.thumbnail(of: thumbnailSize, for: .mediaBox)
        } catch {
            print("Error generating PDF thumbnail: \(error)")
            return nil
        }
    }

    /// Process a PDF file at the given URL (async/await version)
    /// - Parameter url: The URL of the PDF file
    /// - Returns: A DocumentAttachment containing the extracted text and metadata
    /// - Throws: PDFError if processing fails
    func processPDF(from url: URL) async throws -> DocumentAttachment {
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? NSNumber {
                if fileSize.int64Value > maxFileSize {
                    throw PDFError.fileTooLarge(maxSize: maxFileSize, actualSize: fileSize.int64Value)
                }
            }
        } catch {
            throw error
        }

        // Load PDF document
        guard let document = PDFDocument(url: url) else {
            throw PDFError.invalidPDF
        }

        // Extract text from PDF
        let extractedText = extractText(from: document)
        let filename = url.lastPathComponent

        // Check if we extracted any text
        if extractedText.isEmpty {
            throw PDFError.noTextFound
        }

        return DocumentAttachment(filename: filename, textContent: extractedText)
    }

    /// Process a PDF file at the given URL
    /// - Parameters:
    ///   - url: The URL of the PDF file
    ///   - completion: Returns the extracted text and filename on success, or an error
    func processPDF(at url: URL, completion: @escaping (Result<(text: String, filename: String), Error>) -> Void) {
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? NSNumber {
                if fileSize.int64Value > maxFileSize {
                    completion(.failure(PDFError.fileTooLarge(maxSize: maxFileSize, actualSize: fileSize.int64Value)))
                    return
                }
            }
        } catch {
            completion(.failure(error))
            return
        }

        // Load PDF document
        guard let document = PDFDocument(url: url) else {
            completion(.failure(PDFError.invalidPDF))
            return
        }

        // Extract text from PDF
        let extractedText = extractText(from: document)
        let filename = url.lastPathComponent

        completion(.success((text: extractedText, filename: filename)))
    }

    /// Extract text content from a PDF document
    /// - Parameter document: The PDF document to extract text from
    /// - Returns: The extracted text content
    private func extractText(from document: PDFDocument) -> String {
        var text = ""

        // Extract text from all pages
        for pageIndex in 0..<document.pageCount {
            if let page = document.page(at: pageIndex),
               let pageText = page.attributedString?.string {
                text += pageText + "\n\n"
            }
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum PDFError: Error, LocalizedError {
    case userCancelled
    case fileTooLarge(maxSize: Int64, actualSize: Int64)
    case invalidPDF
    case noTextFound

    var errorDescription: String? {
        switch self {
        case .userCancelled:
            return "PDF selection was cancelled"
        case .fileTooLarge(let maxSize, let actualSize):
            let maxMB = Double(maxSize) / (1024 * 1024)
            let actualMB = Double(actualSize) / (1024 * 1024)
            return "PDF file is too large. Maximum size is \(String(format: "%.1f", maxMB))MB, but file is \(String(format: "%.1f", actualMB))MB."
        case .invalidPDF:
            return "The selected file is not a valid PDF document"
        case .noTextFound:
            return "No text content found in the PDF document"
        }
    }
}