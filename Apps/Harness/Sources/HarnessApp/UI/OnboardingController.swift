import AppKit
import HarnessOnboarding

/// First-run onboarding entry point. Delegates to the immersive `HarnessOnboarding` wizard
/// (a borderless glass takeover embedded in the app) — shown once on first launch and
/// re-openable any time from **Help → Welcome to Harness**.
///
/// The wizard owns its own window lifetime and first-run flag; this enum is the thin,
/// stable surface the rest of the app (`AppDelegate`, `MainMenuBuilder`) calls.
@MainActor
enum OnboardingController {
    /// Present on first run only.
    static func presentIfNeeded() {
        HarnessOnboarding.presentIfNeeded()
    }

    /// Always present (Help menu).
    static func present() {
        HarnessOnboarding.present()
    }
}
