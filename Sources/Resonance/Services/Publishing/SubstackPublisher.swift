import UIKit
import MessageUI
import Foundation

/// Substack doesn't have a public write API.
/// This publisher opens a pre-filled mail compose sheet (email-to-post).
/// The `blogURL` field stores the Substack email address (e.g. "mypub@substack.com").
final class SubstackPublisher: NSObject, BlogPublisher {
    let platformType: BlogPlatform = .substack

    func publish(article: Article, config: BlogPlatformConfig, asDraft: Bool) async throws -> PublishResult {
        guard !config.blogURL.isEmpty else {
            throw PublishingError.missingCredentials
        }

        guard MFMailComposeViewController.canSendMail() else {
            throw PublishingError.apiError(statusCode: 0, message: "Mail is not configured on this device. Please set up Mail app first.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                let composer = MFMailComposeViewController()
                composer.mailComposeDelegate = SubstackMailDelegate.shared
                composer.setToRecipients([config.blogURL])
                composer.setSubject(article.title)
                composer.setMessageBody(article.body, isHTML: false)

                SubstackMailDelegate.shared.completion = { result in
                    switch result {
                    case .success:
                        // Substack email-to-post doesn't return a URL immediately
                        let placeholderURL = URL(string: "https://substack.com")!
                        continuation.resume(returning: PublishResult(
                            url: placeholderURL,
                            postId: UUID().uuidString,
                            publishedAt: .now
                        ))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }

                guard let topVC = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first?.windows.first?.rootViewController
                else {
                    continuation.resume(throwing: PublishingError.apiError(statusCode: 0, message: "No view controller to present from"))
                    return
                }
                topVC.present(composer, animated: true)
            }
        }
    }

    func validateCredentials(config: BlogPlatformConfig) async throws -> Bool {
        return !config.blogURL.isEmpty && config.blogURL.contains("@")
    }
}

// MARK: - Mail Delegate Helper

final class SubstackMailDelegate: NSObject, MFMailComposeViewControllerDelegate {
    static let shared = SubstackMailDelegate()
    var completion: ((Result<Void, Error>) -> Void)?

    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true) { [weak self] in
            if let error { self?.completion?(.failure(error)); return }
            switch result {
            case .sent:    self?.completion?(.success(()))
            case .saved:   self?.completion?(.success(()))
            case .failed:  self?.completion?(.failure(PublishingError.apiError(statusCode: 0, message: "Mail sending failed")))
            case .cancelled: self?.completion?(.failure(PublishingError.apiError(statusCode: 0, message: "Cancelled")))
            @unknown default: self?.completion?(.failure(PublishingError.apiError(statusCode: 0, message: "Unknown result")))
            }
        }
    }
}
