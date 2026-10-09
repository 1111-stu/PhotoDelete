//
//  PaywallLegalLinks.swift
//  PhotoDelete
//
//  隐私政策 / 使用条款链接行。付费页与进阶页锁定底栏共用，
//  accessibility identifier 是 UI 测试契约的一部分，不要改名。
//

import SwiftUI

struct SupporterLegalLinksRow: View {
    var body: some View {
        HStack(spacing: PaywallDS.Space.md) {
            Link(L10n.string("Privacy Policy"), destination: AppConstants.privacyPolicyURL)
                .accessibilityIdentifier("supporter-privacy-policy-link")

            Text("·")
                .accessibilityHidden(true)

            Link(L10n.string("Terms of Use"), destination: AppConstants.termsOfUseURL)
                .accessibilityIdentifier("supporter-terms-of-use-link")
        }
        .font(PaywallDS.Font.captionSemibold)
        .foregroundColor(PaywallDS.Color.textSecondary)
    }
}
