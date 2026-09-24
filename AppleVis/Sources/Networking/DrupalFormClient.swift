import Foundation
import os

/// Drupal HTML form submission — ported from src/services/drupalForm.ts.
///
/// Blog, bug report, and podcast submission are Drupal webforms / contact
/// forms with no REST/JSON:API create endpoint. The only way to submit is to
/// replicate what a browser does: GET the form page (session cookie carries
/// auth automatically via the shared URLSession cookie store), scrape the
/// one-time CSRF tokens out of the HTML, then POST the encoded body and
/// detect success by whether the response redirected away from the form URL.
///
/// Verified live: the `/contact` form's token extraction (form_build_id,
/// captcha_sid, captcha_token) matches this parsing exactly. Blog/bug
/// submission require an authenticated session to even reach the real form
/// (anonymous requests redirect to a login page) — the token-scraping and
/// POST logic is identical, ported faithfully from the RN reference, but
/// could not be end-to-end verified against a live authenticated session.
enum DrupalFormClient {
    private static let base = "https://www.applevis.com"

    // Same Cloudflare-bypass headers as APIClient (see CloudflareBypass.swift)
    // — this client uses URLSession.shared, not APIClient's session, so it
    // still needs them applied explicitly per-request.
    private static let bypassHeaders: [String: String] = CloudflareBypass.headers(origin: base)

    private static func applyBypassHeaders(to request: inout URLRequest) {
        bypassHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }
    }

    enum FormResult {
        case ok
        case failure(String)
    }

    private struct FormTokens {
        let formBuildId: String
        let formToken: String
        let honeypotTime: String
    }

    /// Previously a bare `nil` on any failure — a form-page fetch that
    /// failed outright (network/HTTP error) and a fetch that succeeded but
    /// no longer contained a `form_build_id` (e.g. the form markup changed
    /// server-side) were indistinguishable from the caller's perspective
    /// and left no trace to tell them apart from, beyond the generic
    /// user-facing "could not load the submission form" string.
    private static func fetchTokens(path: String) async -> FormTokens? {
        guard let url = URL(string: "\(base)\(path)") else {
            AppLog.network.error("Invalid form URL for path \(path, privacy: .public)")
            return nil
        }
        var request = URLRequest(url: url)
        applyBypassHeaders(to: &request)
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await URLSession.shared.data(for: request) else {
            AppLog.network.error("Form page fetch failed for \(path, privacy: .public)")
            return nil
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            AppLog.network.error("Form page fetch for \(path, privacy: .public) returned status \(status)")
            return nil
        }
        guard let html = String(data: data, encoding: .utf8) else {
            AppLog.network.error("Form page response for \(path, privacy: .public) was not valid UTF-8")
            return nil
        }

        let formBuildId = firstMatch(#"name="form_build_id"\s+value="([^"]+)""#, in: html)
        let formToken = firstMatch(#"name="form_token"\s+value="([^"]+)""#, in: html)
        let honeypotTime = firstMatch(#"name="honeypot_time"\s+value="([^"]+)""#, in: html)
        guard let formBuildId, !formBuildId.isEmpty else {
            AppLog.network.error("No form_build_id found scraping \(path, privacy: .public) — form markup may have changed")
            return nil
        }
        return FormTokens(formBuildId: formBuildId, formToken: formToken ?? "", honeypotTime: honeypotTime ?? "")
    }

    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[range])
    }

    private static func encodeFields(_ fields: [String: String]) -> Data {
        fields.map { "\($0.key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
            .joined(separator: "&")
            .data(using: .utf8) ?? Data()
    }

    /// Drupal redirects on a successful submission; a form error re-renders the same URL.
    private static func wasRedirected(_ response: URLResponse, from path: String) -> Bool {
        guard let url = response.url?.absoluteString else { return false }
        return !url.hasPrefix("\(base)\(path)")
    }

    private static func postForm(path: String, body: Data, contentType: String) async -> FormResult {
        guard let url = URL(string: "\(base)\(path)") else { return .failure(String(localized: "Invalid form URL.")) }
        var request = URLRequest(url: url)
        applyBypassHeaders(to: &request)
        request.httpMethod = "POST"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = body
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if wasRedirected(response, from: path) {
                return .ok
            }
            AppLog.network.error("Form POST to \(path, privacy: .public) was not redirected — likely a form validation error")
            return .failure(String(localized: "The submission was not accepted. Please check your content and try again."))
        } catch {
            AppLog.network.error("Form POST to \(path, privacy: .public) failed: \(error, privacy: .private)")
            return .failure(String(localized: "Couldn't reach AppleVis. Check your connection and try again."))
        }
    }

    // MARK: - Blog submission (/form/blog-submission)

    static func submitBlog(name: String, email: String, message: String, blogDraft: String) async -> FormResult {
        let path = "/form/blog-submission"
        guard let tokens = await fetchTokens(path: path) else {
            return .failure(String(localized: "Could not load the submission form. Check your connection and try again."))
        }
        let body = encodeFields([
            "name": name, "email": email, "message": message, "blog_draft": blogDraft,
            "form_build_id": tokens.formBuildId, "form_token": tokens.formToken,
            "form_id": "webform_submission_blog_submission_add_form",
            // Verified live against the real submit button's value — was
            // the generic "Submit" before, which doesn't match what the
            // actual form sends. Reported directly.
            "op": "Submit Blog Post",
        ])
        return await postForm(path: path, body: body, contentType: "application/x-www-form-urlencoded")
    }

    // MARK: - Bug report (/form/community-bug-report-form)

    static func submitBug(
        name: String, email: String, title: String, appleFeedback: String,
        platform: String, softwareVersion: String, canReproduce: String,
        description: String, recognition: String
    ) async -> FormResult {
        let path = "/form/community-bug-report-form"
        guard let tokens = await fetchTokens(path: path) else {
            return .failure(String(localized: "Could not load the submission form. Check your connection and try again."))
        }
        let body = encodeFields([
            "your_name": name, "email": email, "title": title, "apple_feedback": appleFeedback,
            "platform": platform, "software_version": softwareVersion,
            "can_you_reproduce_the_issue": canReproduce, "description": description,
            "may_we_thank_and_publicly_recognize_you_for_your_efforts_in_our": recognition,
            "form_build_id": tokens.formBuildId, "form_token": tokens.formToken,
            "form_id": "webform_submission_community_bug_report_form_add_form", "op": "Submit",
        ])
        return await postForm(path: path, body: body, contentType: "application/x-www-form-urlencoded")
    }

    // MARK: - Podcast submission (/podcasts/upload) — multipart, includes an audio file

    /// Verified live against the real /podcasts/upload form: for a
    /// signed-in submitter (the only way this screen is ever reached —
    /// see `SubmitPodcastView`'s sign-in gate), "Your name" and "Your
    /// email address" are rendered as plain read-only text (Drupal `item`
    /// elements, populated from the account) with no `<input>` at all —
    /// no `name="name"`/`name="mail"` field exists on the real form to
    /// submit in the first place. A previous pass here added a `name`/
    /// `email` parameter on the same reasoning that correctly fixed Blog
    /// and Bug's genuinely-required email fields; checked directly against
    /// this form's own live HTML and that reasoning doesn't apply here.
    /// Reverted. Reported directly.
    static func submitPodcast(description: String, audioFileName: String?, audioFileData: Data?) async -> FormResult {
        // The caller reads the file into memory itself (while its
        // security-scoped access is valid) and hands us bytes, not a URL —
        // this used to be `try? Data(contentsOf: audioFileURL)` here, which
        // silently produced nil (and thus a file-less submission with no
        // error) for any file outside the sandbox, since no security scope
        // was ever opened at this point in time.
        guard let audioFileData, let audioFileName else {
            return .failure(String(localized: "No audio file was attached. Please choose an audio file and try again."))
        }
        let path = "/podcasts/upload"
        guard let tokens = await fetchTokens(path: path) else {
            return .failure(String(localized: "Could not load the submission form. Check your connection and try again."))
        }
        guard let url = URL(string: "\(base)\(path)") else { return .failure(String(localized: "Invalid form URL.")) }

        let boundary = "AppleVisBoundary-\(UUID().uuidString)"
        var body = Data()
        func appendField(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        appendField("field_description[0][value]", description)
        appendField("field_podcast_file[0][display]", "1")
        appendField("field_podcast_file[0][fids]", "")
        appendField("honeypot_time", tokens.honeypotTime)
        appendField("form_build_id", tokens.formBuildId)
        appendField("form_token", tokens.formToken)
        appendField("form_id", "contact_message_submit_podcast_form")
        appendField("url", "")
        appendField("op", "Send message")

        let mimeType = mimeType(for: URL(fileURLWithPath: audioFileName))
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"files[field_podcast_file_0]\"; filename=\"\(audioFileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(audioFileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: url)
        applyBypassHeaders(to: &request)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = body

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if wasRedirected(response, from: path) {
                return .ok
            }
            AppLog.network.error("Podcast upload POST to \(path, privacy: .public) was not redirected — likely a form validation error")
            return .failure(String(localized: "The submission was not accepted. Please check your content and try again."))
        } catch {
            AppLog.network.error("Podcast upload POST to \(path, privacy: .public) failed: \(error, privacy: .private)")
            return .failure(String(localized: "Couldn't reach AppleVis. Check your connection and try again."))
        }
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "mp3": return "audio/mpeg"
        case "m4a", "mp4": return "audio/mp4"
        case "wav": return "audio/x-wav"
        default: return "application/octet-stream"
        }
    }

    // MARK: - Contact form (/contact)
    //
    // The signed-in and signed-out renders of this form are not the same
    // markup: a saved copy of the real page from an authenticated session
    // (docs reference: "Contact AppleVis _ AppleVis.html") has a
    // `form_token` hidden field and no CAPTCHA fields at all, while the
    // "verified live" pass this was originally written against apparently
    // saw the opposite — a `captcha_sid`/`captcha_token`/`captcha_response`
    // triad and no `form_token`. Both are Drupal's normal behavior: an
    // authenticated session is trusted and skips the bot-check challenge
    // anonymous visitors get. Sending neither one when it's present makes
    // Drupal's own CSRF/form-token validation reject the POST outright —
    // this previously omitted `form_token` unconditionally, which would
    // silently fail every submission from a signed-in user (the common
    // case: ContactView skips straight to the signed-in flow, and
    // ReportCommentWizard is signed-in-first too) while still "working"
    // for the signed-out path this was tested against. Scraping and
    // sending both, each defaulting to empty when absent, matches whichever
    // variant the live session actually renders instead of assuming one.
    static func submitContact(name: String, email: String, subject: String, message: String) async -> FormResult {
        let path = "/contact"
        guard let url = URL(string: "\(base)\(path)") else { return .failure(String(localized: "Invalid form URL.")) }
        var pageRequest = URLRequest(url: url)
        applyBypassHeaders(to: &pageRequest)
        pageRequest.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")

        guard let (data, pageResponse) = try? await URLSession.shared.data(for: pageRequest),
              let http = pageResponse as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8)
        else {
            AppLog.network.error("Contact form page fetch failed for \(path, privacy: .public)")
            return .failure(String(localized: "Could not load the contact form. Check your connection and try again."))
        }

        guard let formBuildId = firstMatch(#"name="form_build_id"\s+value="([^"]+)""#, in: html), !formBuildId.isEmpty else {
            AppLog.network.error("No form_build_id found scraping \(path, privacy: .public) — form markup may have changed")
            return .failure(String(localized: "Could not load the contact form. Check your connection and try again."))
        }
        let formToken = firstMatch(#"name="form_token"\s+value="([^"]+)""#, in: html) ?? ""
        let captchaSid = firstMatch(#"name="captcha_sid"\s+value="([^"]+)""#, in: html) ?? ""
        let captchaToken = firstMatch(#"name="captcha_token"\s+value="([^"]+)""#, in: html) ?? ""
        let captchaResponse = firstMatch(#"name="captcha_response"\s+value="([^"]+)""#, in: html) ?? "Turnstile no captcha"

        let body = encodeFields([
            "i_understand_that_applevis_does_not_accept_sponsored_posts_conte": "1",
            "name": name, "email": email, "subject": subject, "message": message,
            "form_token": formToken,
            "captcha_sid": captchaSid, "captcha_token": captchaToken,
            "captcha_response": captchaResponse, "captcha_cacheable": "1",
            "form_build_id": formBuildId, "form_id": "webform_submission_contact_node_25142_add_form",
            "url": "", "op": "Send message",
        ])
        return await postForm(path: path, body: body, contentType: "application/x-www-form-urlencoded")
    }
}
