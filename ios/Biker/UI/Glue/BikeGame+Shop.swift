import Foundation

/// Buying, equipping, upgrades, the daily reward and achievement toasts.
extension BikeGame {
    // MARK: - Skins

    /// Equips an owned skin or buys one that can be bought (and equips it).
    func tapSkin(id: String) {
        guard let info = Catalog.info(id: id) else { return }
        if profile.owns(id: id) {
            equip(info)
        } else {
            buy(info)
        }
    }

    /// Shows a skin on the bike in the garage without buying it.
    func preview(id: String) {
        dressWorld(preview: Catalog.info(id: id))
        notices.clearMessage()
    }

    private func equip(_ info: SkinInfo) {
        guard !profile.isSelected(id: info.id) else { return }
        var updated = profile
        guard updated.select(id: info.id) else { return }
        commit(updated)
        sound.play(.button)
        haptics.tick()
        dressWorld()
    }

    private func buy(_ info: SkinInfo) {
        let before = profile
        var updated = profile
        switch updated.buySkin(id: info.id) {
        case .bought:
            updated.select(id: info.id)
            commit(updated)
            sound.play(.purchase)
            haptics.success()
            notices.clearMessage()
            notices.toast("Куплено!", info.name, tone: .info, now: now)
            announceAchievements(since: before)
            dressWorld()
        case .notEnoughCoins:
            refuse("Не хватает \(info.price - profile.coins) говнокоинов")
        case .lockedByAchievement:
            refuse(lockText(info))
        case .alreadyOwned, .unknownItem, .maxedOut:
            break
        }
    }

    func lockText(_ info: SkinInfo) -> String {
        guard let source = info.unlockedBy, let achievement = Achievement.find(source) else {
            return "Пока закрыто"
        }
        return "Даётся за «\(achievement.name)»"
    }

    // MARK: - Upgrades

    func buyUpgrade(_ track: UpgradeTrack) {
        let before = profile
        var updated = profile
        switch updated.buyUpgrade(track) {
        case .bought:
            commit(updated)
            sound.play(.upgrade)
            haptics.success()
            notices.clearMessage()
            announceAchievements(since: before)
        case .notEnoughCoins:
            let price = profile.nextPrice(of: track) ?? 0
            refuse("Не хватает \(price - profile.coins) говнокоинов")
        case .maxedOut:
            refuse("Уже прокачано до упора")
        case .alreadyOwned, .lockedByAchievement, .unknownItem:
            break
        }
    }

    private func refuse(_ text: String) {
        notices.say(text, now: now)
        haptics.failure()
        sound.play(.button)
    }

    // MARK: - Daily reward

    private var secondsFromGMT: Int { TimeZone.current.secondsFromGMT(for: Date()) }

    var canClaimDaily: Bool {
        profile.canClaimDaily(now: Date(), secondsFromGMT: secondsFromGMT)
    }

    var dailyRewardPreview: Int {
        profile.nextDailyReward(now: Date(), secondsFromGMT: secondsFromGMT)
    }

    func claimDaily() {
        let before = profile
        var updated = profile
        switch updated.claimDaily(now: Date(), secondsFromGMT: secondsFromGMT) {
        case .claimed(let reward, let streak):
            commit(updated)
            sound.play(.purchase)
            haptics.success()
            notices.toast("Ежедневный подгон", "+\(reward) говнокоинов, день \(streak)", tone: .reward, now: now)
            announceAchievements(since: before)
        case .alreadyClaimed:
            notices.say("Сегодня уже забрал, приходи завтра", now: now)
        }
    }

    // MARK: - Achievements

    /// Toasts every achievement the profile has now and did not have in `before`.
    func announceAchievements(since before: Profile) {
        for id in AchievementID.allCases where profile.hasAchievement(id) && !before.hasAchievement(id) {
            guard let achievement = Achievement.find(id) else { continue }
            notices.toast(achievement.name, rewardText(achievement), tone: .achievement, now: now)
        }
    }

    private func rewardText(_ achievement: Achievement) -> String {
        var parts: [String] = []
        if achievement.reward > 0 { parts.append("+\(achievement.reward) говнокоинов") }
        let skins = Catalog.skinIds(unlockedBy: achievement.id).compactMap { Catalog.info(id: $0)?.name }
        if !skins.isEmpty { parts.append("открыто: " + skins.joined(separator: ", ")) }
        return parts.isEmpty ? achievement.description : parts.joined(separator: ", ")
    }
}
