import SwiftUI
import Domain

struct ProviderDetailView: View {
    let snapshot: UsageSnapshot

    var body: some View {
        List {
            // Account Info
            if snapshot.accountEmail != nil || snapshot.accountTier != nil {
                Section("Account") {
                    if let email = snapshot.accountEmail {
                        LabeledContent("Email", value: email)
                    }
                    if let org = snapshot.accountOrganization {
                        LabeledContent("Organization", value: org)
                    }
                    if let tier = snapshot.accountTier {
                        LabeledContent("Plan", value: tier.displayName)
                    }
                }
            }

            // Quotas
            if !snapshot.quotas.isEmpty {
                Section("Quotas") {
                    ForEach(snapshot.quotas, id: \.self) { quota in
                        QuotaRow(quota: quota)
                    }
                }
            }

            // Cost Usage
            if let cost = snapshot.costUsage {
                Section("Usage") {
                    LabeledContent("Cost", value: cost.formattedCost)
                    if let budget = cost.formattedBudget {
                        LabeledContent("Budget", value: budget)
                    }
                    LabeledContent("API Time", value: cost.formattedApiDuration)
                    if cost.wallDuration > 0 {
                        LabeledContent("Wall Time", value: cost.formattedWallDuration)
                    }
                    if cost.linesAdded > 0 || cost.linesRemoved > 0 {
                        LabeledContent("Code Changes", value: cost.formattedCodeChanges)
                    }
                }
            }

            // Freshness
            Section {
                LabeledContent("Last Synced", value: snapshot.ageDescription)
            }
        }
        .navigationTitle(ProviderIcons.displayName(for: snapshot.providerId))
    }
}

// MARK: - Quota Row

private struct QuotaRow: View {
    let quota: UsageQuota

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(quota.quotaType.displayName)
                    .font(.subheadline.weight(.medium))

                Spacer()

                if let dollar = quota.formattedDollarRemaining {
                    Text(dollar)
                        .font(.subheadline.monospacedDigit())
                } else {
                    Text("\(Int(quota.percentRemaining))% remaining")
                        .font(.subheadline.monospacedDigit())
                }
            }

            ProgressView(value: max(0, min(1, quota.percentRemaining / 100)))
                .tint(progressColor)

            HStack {
                statusBadge

                Spacer()

                if let reset = quota.resetDescription {
                    Text(reset)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var progressColor: Color {
        switch quota.status {
        case .healthy: .green
        case .warning: .yellow
        case .critical: .red
        case .depleted: .gray
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        let (text, color): (String, Color) = switch quota.status {
        case .healthy: ("Healthy", .green)
        case .warning: ("Warning", .yellow)
        case .critical: ("Critical", .red)
        case .depleted: ("Depleted", .gray)
        }

        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}
