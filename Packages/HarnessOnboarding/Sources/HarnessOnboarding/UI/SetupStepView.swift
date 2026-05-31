import SwiftUI
import AppKit

/// One-click setup. Behavior stays in BinaryInstaller; the UI is reduced to status, action, and recovery text.
struct SetupStepView: View {
    @State private var cliStatus = BinaryInstaller.detectCLI()
    @State private var daemonStatus = BinaryInstaller.detectDaemon()
    @State private var isInstalling = false
    @State private var installReport: BinaryInstaller.InstallReport?
    @State private var errorMessage: String?

    private var canInstall: Bool { cliStatus.isReady || daemonStatus.isReady }
    private var isSuccess: Bool { installReport != nil && errorMessage == nil }

    var body: some View {
        VStack(spacing: 24) {
            StepIntro(
                eyebrow: "Install",
                title: isSuccess ? "Harness is installed." : "Install the local tools.",
                bodyText: isSuccess
                    ? "The CLI and daemon are in place. The LaunchAgent is registered for your user account."
                    : "Harness copies the CLI and daemon into your Library, then sets up the background process."
            )

            VStack(spacing: 0) {
                statusRow(title: "CLI", detail: "harness-cli", status: cliStatus)
                    .padding(.vertical, 13)
                Rectangle().fill(.white.opacity(0.075)).frame(height: 1)
                statusRow(title: "Daemon", detail: "HarnessDaemon", status: daemonStatus)
                    .padding(.vertical, 13)
            }
            .frame(maxWidth: 500)

            if let report = installReport {
                Text(report.messages.joined(separator: "  /  "))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.38))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
                    .transition(.opacity)
            } else if let err = errorMessage {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundStyle(ImmersivePalette.SUI.danger)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .frame(maxWidth: 500)
            }

            if !isSuccess {
                Button(action: performInstall) {
                    if isInstalling {
                        ProgressView().controlSize(.small)
                    } else {
                        Text(canInstall ? "Install" : "No binaries found")
                    }
                }
                .buttonStyle(GlassPrimaryButtonStyle(minWidth: 140))
                .disabled(isInstalling || !canInstall)
            } else {
                StatusPill(text: "ready", tone: .success)
            }
        }
        .animation(Motion.spring, value: isSuccess)
        .onAppear {
            if case .willInstall = cliStatus { cliStatus = BinaryInstaller.detectCLI() }
            if case .willInstall = daemonStatus { daemonStatus = BinaryInstaller.detectDaemon() }
        }
    }

    private func statusRow(title: String, detail: String, status: BinaryInstaller.DetectionStatus) -> some View {
        QuietRow(title: title, detail: detail, value: status.display, tone: tone(for: status))
    }

    private func tone(for status: BinaryInstaller.DetectionStatus) -> StatusPill.Tone {
        switch status {
        case .found:       .success
        case .willInstall: .pending
        case .notFound:    .neutral
        }
    }

    private func performInstall() {
        guard !isInstalling else { return }
        isInstalling = true
        errorMessage = nil

        Task {
            do {
                let cliSrc = cliStatus.asFoundPath()
                let daemonSrc = daemonStatus.asFoundPath()
                let report = try BinaryInstaller.performInstall(cliSource: cliSrc, daemonSource: daemonSrc)
                installReport = report
                cliStatus = BinaryInstaller.detectCLI()
                daemonStatus = BinaryInstaller.detectDaemon()
                NSSound(named: "Glass")?.play()
            } catch {
                errorMessage = "Install failed: \(error.localizedDescription)\nRun `harness-cli install` from Harness.app or a build output."
            }
            isInstalling = false
        }
    }
}

extension BinaryInstaller.DetectionStatus {
    func asFoundPath() -> URL? {
        if case .found(_, let path) = self { return path }
        return nil
    }
}
