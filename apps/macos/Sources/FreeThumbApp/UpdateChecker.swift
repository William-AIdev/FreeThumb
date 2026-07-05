import Foundation
import FreeThumbCore

let defaultUpdateManifestURL =
  "https://raw.githubusercontent.com/William-AIdev/FreeThumb/main/update-manifest.json"

@MainActor
final class UpdateChecker: ObservableObject {
  @Published private(set) var isChecking = false
  @Published private(set) var statusMessage: String?
  @Published private(set) var downloadURL: URL?

  var currentVersion: String {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
  }

  func check(manifestURLString: String) {
    guard
      let manifestURL = URL(string: manifestURLString.trimmingCharacters(in: .whitespaces)),
      manifestURL.scheme?.lowercased() == "https"
    else {
      statusMessage = "Enter the HTTPS release manifest URL first."
      downloadURL = nil
      return
    }

    isChecking = true
    statusMessage = nil
    downloadURL = nil
    Task {
      defer { isChecking = false }
      do {
        let (data, response) = try await URLSession.shared.data(from: manifestURL)
        guard let response = response as? HTTPURLResponse,
          (200..<300).contains(response.statusCode)
        else {
          throw UpdateCheckError.invalidResponse
        }
        let manifest = try JSONDecoder().decode(UpdateManifest.self, from: data)
        guard manifest.downloadURL.scheme?.lowercased() == "https" else {
          throw UpdateCheckError.invalidDownloadURL
        }

        if VersionComparison.isNewer(manifest.version, than: currentVersion) {
          statusMessage = "Version \(manifest.version) is available."
          downloadURL = manifest.downloadURL
        } else {
          statusMessage = "FreeThumb \(currentVersion) is up to date."
        }
      } catch {
        statusMessage = "Update check failed: \(error.localizedDescription)"
      }
    }
  }
}

private struct UpdateManifest: Decodable {
  let version: String
  let downloadURL: URL
}

private enum UpdateCheckError: LocalizedError {
  case invalidResponse
  case invalidDownloadURL

  var errorDescription: String? {
    switch self {
    case .invalidResponse: "The update server returned an invalid response."
    case .invalidDownloadURL: "The update download URL must use HTTPS."
    }
  }
}
