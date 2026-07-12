import SwiftUI

/// The 340pt featured card: photo, dark fade, countdown chip, meta row.
struct HeroVaultCard: View {
    let vault: Vault

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CoverArt(vault: vault, dimmed: true)

            LinearGradient(
                stops: [
                    .init(color: Color(hex: "0A0F1C").opacity(0.15), location: 0),
                    .init(color: Color(hex: "0A0F1C").opacity(0.15), location: 0.35),
                    .init(color: Color(hex: "0A0F1C").opacity(0.96), location: 1),
                ],
                startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 0) {
                Text("Your next reveal")
                    .monoLabel(size: 10.5, color: .poolGold, tracking: 1.3)

                Text(vault.displayName)
                    .font(CapsuleFont.display(28, .extraBold))
                    .foregroundStyle(Color.capsuleCream)
                    .padding(.top, 6)

                HStack(spacing: 14) {
                    metaItem("lock.fill", "Memories locked")
                    metaItem("person.2.fill", "\(vault.members.count) friends")
                    metaItem(nil, "\(vault.memoryCount) memories")
                }
                .padding(.top, 10)

                if let unlockDate = vault.unlockDate, vault.state != .unlocked {
                    CountdownChip(target: unlockDate)
                        .padding(.top, 14)
                }
            }
            .padding(20)
        }
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.6), radius: 25, y: 20)
    }

    private func metaItem(_ icon: String?, _ text: String) -> some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            }
            Text(text).font(CapsuleFont.body(12, .semibold))
        }
        .foregroundStyle(Color.capsuleDim)
    }
}

/// Compact live countdown pill (`.hero-countdown`), showing the 2 largest units.
struct CountdownChip: View {
    let target: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let parts = CountdownParts(from: context.date, to: target)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                unit(parts.primaryValue, parts.primaryLabel)
                unit(parts.secondaryValue, parts.secondaryLabel)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.28), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 1))
        }
    }

    private func unit(_ value: Int, _ label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text("\(value)")
                .font(CapsuleFont.display(22, .extraBold))
                .foregroundStyle(Color.poolGold)
            Text(label)
                .monoLabel(size: 10.5, color: .capsuleDim, tracking: 0.9)
        }
    }
}

/// Countdown decomposition shared by home chip and waiting screen.
struct CountdownParts {
    let days: Int, hours: Int, minutes: Int, seconds: Int
    let isPast: Bool

    init(from now: Date, to target: Date) {
        let interval = max(0, target.timeIntervalSince(now))
        isPast = target <= now
        let total = Int(interval)
        days = total / 86400
        hours = (total % 86400) / 3600
        minutes = (total % 3600) / 60
        seconds = total % 60
    }

    var primaryValue: Int { days > 0 ? days : hours }
    var primaryLabel: String { days > 0 ? "days" : "hrs" }
    var secondaryValue: Int { days > 0 ? hours : minutes }
    var secondaryLabel: String { days > 0 ? "hrs" : "mins" }
}

/// 132×168 mini card for the horizontal rows.
struct MiniVaultCard: View {
    let vault: Vault
    let locked: Bool

    private var statusText: String {
        if locked {
            let total = vault.members.count
            return "\(vault.readyCount) of \(total) in"
        }
        return "\(vault.memoryCount) memories"
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CoverArt(vault: vault, dimmed: locked)
                .blur(radius: locked ? 2.5 : 0)
                .saturation(locked ? 0.6 : 1)

            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.4),
                    .init(color: Color(hex: "0A0F1C").opacity(0.92), location: 1),
                ],
                startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 3) {
                Text(vault.name)
                    .font(CapsuleFont.display(13, .bold))
                    .foregroundStyle(Color.capsuleCream)
                    .lineLimit(1)
                Text(statusText)
                    .monoLabel(size: 9, color: locked ? .poolCoral : .poolEmerald, tracking: 0.5)
            }
            .padding(12)
        }
        .frame(width: 132, height: 168)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            if locked {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.capsuleCream)
                    .frame(width: 26, height: 26)
                    .background(Color.black.opacity(0.4), in: Circle())
                    .padding(10)
            }
        }
    }
}
