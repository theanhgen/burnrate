import SwiftUI
import Domain

struct ProviderListView: View {
    @Bindable var viewModel: SnapshotViewModel

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("burnrate")
                .refreshable {
                    await viewModel.refresh()
                }
                .task {
                    if viewModel.snapshots.isEmpty {
                        await viewModel.refresh()
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.snapshots.isEmpty {
            ProgressView("Loading...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, viewModel.snapshots.isEmpty {
            ContentUnavailableView {
                Label("No Data", systemImage: "icloud.slash")
            } description: {
                Text(error)
            } actions: {
                Button("Retry") {
                    Task { await viewModel.refresh() }
                }
            }
        } else if viewModel.activeSnapshots.isEmpty {
            ContentUnavailableView {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
            } description: {
                Text("Open burnrate on your Mac to sync quota data via iCloud.")
            }
        } else {
            List(viewModel.activeSnapshots, id: \.providerId) { snapshot in
                NavigationLink(value: snapshot.providerId) {
                    ProviderRow(snapshot: snapshot)
                }
            }
            .navigationDestination(for: String.self) { providerId in
                if let snapshot = viewModel.snapshots.first(where: { $0.providerId == providerId }) {
                    ProviderDetailView(snapshot: snapshot)
                }
            }
        }
    }
}

// MARK: - Provider Row

private struct ProviderRow: View {
    let snapshot: UsageSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(ProviderIcons.assetName(for: snapshot.providerId))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                Text(ProviderIcons.displayName(for: snapshot.providerId))
                    .font(.headline)

                if let tier = snapshot.accountTier {
                    Text(tier.badgeText)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }

                Spacer()

                Text(snapshot.ageDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                if let session = snapshot.sessionQuota {
                    QuotaBar(label: "Session", quota: session)
                }
                if let weekly = snapshot.weeklyQuota {
                    QuotaBar(label: "Weekly", quota: weekly)
                }
            }

            if let cost = snapshot.costUsage {
                Text(cost.formattedCost)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Quota Bar

private struct QuotaBar: View {
    let label: String
    let quota: UsageQuota

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(quota.percentRemaining))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.quaternary)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(barColor)
                        .frame(width: geo.size.width * max(0, min(1, quota.percentRemaining / 100)))
                }
            }
            .frame(height: 6)
        }
    }

    private var barColor: Color {
        switch quota.status {
        case .healthy: .green
        case .warning: .yellow
        case .critical: .red
        case .depleted: .gray
        }
    }
}

// MARK: - Provider Icons

enum ProviderIcons {
    static func assetName(for providerId: String) -> String {
        switch providerId {
        case "claude": "ClaudeIcon"
        case "codex": "CodexIcon"
        case "gemini": "GeminiIcon"
        case "copilot": "CopilotIcon"
        case "antigravity": "AntigravityIcon"
        case "zai": "ZaiIcon"
        case "bedrock": "BedrockIcon"
        case "ampcode": "AmpCodeIcon"
        case "kimi": "KimiIcon"
        case "minimax": "MiniMaxIcon"
        case "cursor": "CursorIcon"
        case "mistral": "MistralIcon"
        default: "AppLogo"
        }
    }

    static func displayName(for providerId: String) -> String {
        switch providerId {
        case "claude": "Claude"
        case "codex": "Codex"
        case "gemini": "Gemini"
        case "copilot": "GitHub Copilot"
        case "antigravity": "Antigravity"
        case "zai": "Z.ai"
        case "bedrock": "AWS Bedrock"
        case "ampcode": "Amp"
        case "kimi": "Kimi"
        case "kiro": "Kiro"
        case "minimax": "MiniMax"
        case "cursor": "Cursor"
        case "mistral": "Mistral"
        default: providerId.capitalized
        }
    }
}
