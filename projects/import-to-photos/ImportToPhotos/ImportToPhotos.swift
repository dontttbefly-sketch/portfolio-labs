import AppKit
import Darwin
import Foundation
import Photos
import UniformTypeIdentifiers

private let uploadedMarkerAttributeName = "local.import-to-photos.uploaded"

private let supportedExtensions: Set<String> = [
    "jpg", "jpeg", "png", "heic", "heif", "gif", "tif", "tiff", "bmp", "webp",
    "dng", "cr2", "cr3", "nef", "arw", "raf", "rw2", "orf"
]

private struct UploadedMarker: Codable {
    let version: Int
    let importedAt: String
    let appIdentifier: String
}

private struct ImportFailure {
    let url: URL
    let message: String
}

private struct ImageSelection {
    let newImages: [URL]
    let skippedImages: [URL]
}

private func defaultImportFolder() -> URL {
    if let configuredFolder = Bundle.main.url(forResource: "DefaultImportFolder", withExtension: "txt"),
       let configuredPath = try? String(contentsOf: configuredFolder, encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines),
       !configuredPath.isEmpty {
        return URL(fileURLWithPath: configuredPath).standardizedFileURL
    }

    let bundleURL = Bundle.main.bundleURL
    if bundleURL.pathExtension.lowercased() == "app" {
        return bundleURL.deletingLastPathComponent().deletingLastPathComponent()
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

private func normalizedInputURLs(from arguments: [String]) -> [URL] {
    let paths = arguments.dropFirst().filter { !$0.hasPrefix("-") }
    if paths.isEmpty {
        return [defaultImportFolder()]
    }
    return paths.map { URL(fileURLWithPath: $0).standardizedFileURL }
}

private func isSupportedImage(_ url: URL, contentType: UTType?) -> Bool {
    let ext = url.pathExtension.lowercased()
    if supportedExtensions.contains(ext) {
        return true
    }

    guard let contentType else {
        return false
    }

    if contentType == .svg || contentType == .pdf || contentType.identifier == "com.apple.icns" {
        return false
    }

    return contentType.conforms(to: .image)
}

private func collectImages(from inputs: [URL]) -> [URL] {
    var seen = Set<String>()
    var results: [URL] = []
    let bundleURL = Bundle.main.bundleURL.standardizedFileURL
    let toolDirectoryPath = bundleURL.pathExtension.lowercased() == "app"
        ? bundleURL.deletingLastPathComponent().path
        : nil
    let resourceKeys: Set<URLResourceKey> = [
        .contentTypeKey,
        .isDirectoryKey,
        .isPackageKey
    ]

    func isInsideToolDirectory(_ url: URL) -> Bool {
        guard let toolDirectoryPath else {
            return false
        }
        let path = url.standardizedFileURL.path
        return path == toolDirectoryPath || path.hasPrefix(toolDirectoryPath + "/")
    }

    func addIfImage(_ url: URL, contentType: UTType?) {
        let standardized = url.standardizedFileURL
        guard !isInsideToolDirectory(standardized) else {
            return
        }
        guard isSupportedImage(standardized, contentType: contentType) else {
            return
        }
        let path = standardized.path
        guard !seen.contains(path) else {
            return
        }
        seen.insert(path)
        results.append(standardized)
    }

    for input in inputs {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: input.path, isDirectory: &isDirectory) else {
            continue
        }

        if !isDirectory.boolValue {
            let values = try? input.resourceValues(forKeys: resourceKeys)
            addIfImage(input, contentType: values?.contentType)
            continue
        }

        guard let enumerator = FileManager.default.enumerator(
            at: input,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else {
            continue
        }

        for case let url as URL in enumerator {
            if isInsideToolDirectory(url) {
                enumerator.skipDescendants()
                continue
            }

            let values = try? url.resourceValues(forKeys: resourceKeys)
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)

            if isDirectory.boolValue {
                let name = url.lastPathComponent
                let ext = url.pathExtension.lowercased()
                if values?.isPackage == true
                    || ext == "app"
                    || ext == "photoslibrary"
                    || ext == "iconset"
                    || name == "ImportToPhotos" {
                    enumerator.skipDescendants()
                }
                continue
            }

            addIfImage(url, contentType: values?.contentType)
        }
    }

    return results.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
}

private func hasUploadedMarker(_ url: URL) -> Bool {
    let result = getxattr(url.path, uploadedMarkerAttributeName, nil, 0, 0, 0)
    return result >= 0
}

private func uploadedMarkerData() throws -> Data {
    let marker = UploadedMarker(
        version: 1,
        importedAt: ISO8601DateFormatter().string(from: Date()),
        appIdentifier: Bundle.main.bundleIdentifier ?? "local.import-to-photos"
    )
    return try JSONEncoder().encode(marker)
}

private func writeUploadedMarker(to url: URL) -> String? {
    do {
        let data = try uploadedMarkerData()
        let result = data.withUnsafeBytes { buffer in
            setxattr(url.path, uploadedMarkerAttributeName, buffer.baseAddress, data.count, 0, 0)
        }
        guard result == 0 else {
            return NSError(domain: NSPOSIXErrorDomain, code: Int(errno)).localizedDescription
        }
        return nil
    } catch {
        return error.localizedDescription
    }
}

private func partitionUploadedImages(_ images: [URL]) -> ImageSelection {
    var newImages: [URL] = []
    var skippedImages: [URL] = []

    for image in images {
        if hasUploadedMarker(image) {
            skippedImages.append(image)
        } else {
            newImages.append(image)
        }
    }

    return ImageSelection(newImages: newImages, skippedImages: skippedImages)
}

private func showAlert(title: String, message: String) {
    DispatchQueue.main.async {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        NSApp.terminate(nil)
    }
}

private func requestPhotosAccess(completion: @escaping (Bool) -> Void) {
    PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
        switch status {
        case .authorized, .limited:
            completion(true)
        default:
            completion(false)
        }
    }
}

private func importImages(
    _ urls: [URL],
    skippedCount: Int,
    index: Int = 0,
    imported: Int = 0,
    importFailures: [ImportFailure] = [],
    markerFailures: [ImportFailure] = []
) {
    guard index < urls.count else {
        if importFailures.isEmpty && markerFailures.isEmpty {
            showAlert(
                title: "Import Complete",
                message: "Imported \(imported) new image(s) into Photos.\nSkipped \(skippedCount) already marked image(s)."
            )
        } else {
            var details: [String] = [
                "Imported \(imported) new image(s) into Photos.",
                "Skipped \(skippedCount) already marked image(s).",
                "Failed to import \(importFailures.count) image(s).",
                "Imported but not marked \(markerFailures.count) image(s)."
            ]

            let failedImports = importFailures.prefix(5).map { "- \($0.url.lastPathComponent): \($0.message)" }
            if !failedImports.isEmpty {
                details.append("\nImport failures:")
                details.append(contentsOf: failedImports)
            }

            let failedMarkers = markerFailures.prefix(5).map { "- \($0.url.lastPathComponent): \($0.message)" }
            if !failedMarkers.isEmpty {
                details.append("\nMarker failures:")
                details.append(contentsOf: failedMarkers)
            }

            showAlert(
                title: "Import Finished With Errors",
                message: details.joined(separator: "\n")
            )
        }
        return
    }

    let url = urls[index]
    PHPhotoLibrary.shared().performChanges({
        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
    }) { success, error in
        var nextImportFailures = importFailures
        var nextMarkerFailures = markerFailures
        let nextImported = imported + (success ? 1 : 0)
        if success {
            if let markerError = writeUploadedMarker(to: url) {
                nextMarkerFailures.append(ImportFailure(url: url, message: markerError))
            }
        } else {
            nextImportFailures.append(ImportFailure(url: url, message: error?.localizedDescription ?? "Unknown error"))
        }
        importImages(
            urls,
            skippedCount: skippedCount,
            index: index + 1,
            imported: nextImported,
            importFailures: nextImportFailures,
            markerFailures: nextMarkerFailures
        )
    }
}

private func printUsage() {
    print("""
    ImportToPhotos

    Usage:
      ImportToPhotos [folder-or-image ...]
      ImportToPhotos --dry-run [folder-or-image ...]

    If no path is provided, the app imports the folder that contains ImportToPhotos.app.
    Successfully imported files are marked with the \(uploadedMarkerAttributeName) extended attribute.
    """)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let launchURLs: [URL]
    private var hasStarted = false

    init(launchURLs: [URL]) {
        self.launchURLs = launchURLs
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            if !self.hasStarted {
                self.start(with: self.launchURLs)
            }
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        if !hasStarted {
            start(with: urls)
        }
    }

    private func start(with urls: [URL]) {
        hasStarted = true
        let inputs = urls.isEmpty ? [defaultImportFolder()] : urls
        let images = collectImages(from: inputs)
        let selection = partitionUploadedImages(images)

        guard !images.isEmpty else {
            showAlert(title: "No Images Found", message: "No supported image files were found in the selected folder.")
            return
        }

        guard !selection.newImages.isEmpty else {
            showAlert(
                title: "No New Photos To Import",
                message: "Skipped \(selection.skippedImages.count) already marked image(s)."
            )
            return
        }

        requestPhotosAccess { allowed in
            guard allowed else {
                showAlert(
                    title: "Photos Access Needed",
                    message: "Allow this app to add photos in System Settings > Privacy & Security > Photos, then run it again."
                )
                return
            }
            importImages(selection.newImages, skippedCount: selection.skippedImages.count)
        }
    }
}

let arguments = CommandLine.arguments
if arguments.contains("--help") || arguments.contains("-h") {
    printUsage()
    exit(0)
}

let inputURLs = normalizedInputURLs(from: arguments)
if arguments.contains("--dry-run") {
    let images = collectImages(from: inputURLs)
    let selection = partitionUploadedImages(images)
    print("Found \(images.count) supported image(s).")
    print("New images: \(selection.newImages.count)")
    print("Skipped marked images: \(selection.skippedImages.count)")

    if !selection.newImages.isEmpty {
        print("\nNew:")
        for image in selection.newImages {
            print("NEW \(image.path)")
        }
    }

    if !selection.skippedImages.isEmpty {
        print("\nSkipped:")
        for image in selection.skippedImages {
            print("SKIPPED \(image.path)")
        }
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate(launchURLs: inputURLs)
app.delegate = delegate
app.run()
