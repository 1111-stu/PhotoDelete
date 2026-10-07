import Foundation
import Testing
@testable import PhotoDelete

struct EnglishSourceLocalizationTests {
    @Test func englishSourceKeysPreserveChineseTranslations() {
        let expectations: [(AppLanguage, String)] = [
            (.en, "Keep First"),
            (.zhHans, "保留首张"),
            (.zhHant, "保留首張")
        ]

        for (language, expected) in expectations {
            #expect(localized("Keep First", in: language) == expected)
        }
    }

    @Test func interpolatedCountsUseEnglishSourceKeys() {
        let count = 7
        let expectations: [(AppLanguage, String)] = [
            (.en, "7 photos"),
            (.zhHans, "7 张照片"),
            (.zhHant, "7 張照片")
        ]

        for (language, expected) in expectations {
            #expect(localized("\(count) photos", in: language) == expected)
        }
    }

    @Test func multipleInterpolatedArgumentsStayInTheirIntendedPositions() {
        let total = 23
        let reviewed = 8
        let expectations: [(AppLanguage, String)] = [
            (.en, "23 photos · 8 reviewed"),
            (.zhHans, "23 张 · 已整理 8 张"),
            (.zhHant, "23 張 · 已整理 8 張")
        ]

        for (language, expected) in expectations {
            #expect(localized("\(total) photos · \(reviewed) reviewed", in: language) == expected)
        }
    }

    @Test func formatStringCountsUseEnglishSourceKeys() {
        let expectations: [(AppLanguage, String)] = [
            (.en, "3 similar candidates"),
            (.zhHans, "3 张相近候选"),
            (.zhHant, "3 張相近候選")
        ]

        for (language, expected) in expectations {
            let format = localized("%lld similar candidates", in: language)
            #expect(String(format: format, Int64(3)) == expected)
        }
    }

    @Test func englishArgumentOrderPreservesChineseYearAndWeekOrder() {
        let week = 24
        let year = 2026
        let expectations: [(AppLanguage, String)] = [
            (.en, "Week 24 of 2026"),
            (.zhHans, "2026 年第 24 周"),
            (.zhHant, "2026 年第 24 周")
        ]

        for (language, expected) in expectations {
            let format = localized("Week %lld of %lld", in: language)
            #expect(String(format: format, Int64(week), Int64(year)) == expected)
        }
    }

    @Test func englishSourceMigrationPreservesStoredChineseIdentifiers() {
        #expect(PhotoCategory(rawValue: "全部照片") == .all)
        #expect(PhotoCategory(rawValue: "未归类照片") == .unclassified)
        #expect(TimeGroup.fromIdentifier("本周的照片") == .thisWeek)
        #expect(TimeGroup.fromIdentifier("更早的照片") == .olderPhotos)
        #expect(AlbumType.fromStoredValue("最近项目") == .recents)
        #expect(AlbumType.fromStoredValue("用户相册") == .userCreated)
    }

    private func localized(_ value: String.LocalizationValue, in language: AppLanguage) -> String {
        String(localized: value, table: "Localizable", bundle: language.localizationBundle)
    }
}
