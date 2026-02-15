//
//  AppGradients.swift
//  PomoDuo
//
//  Created by Codex on 2/15/26.
//

import SwiftUI

/// Reusable gradient styles for the app shell and timer presentation.
enum AppGradients {
    /// Horizontal lilac banner gradient at the top of the main timer screen.
    static let banner = LinearGradient(
        colors: [AppColors.lilac, AppColors.paleViolet],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Soft fade from banner into the white content surface.
    static let bannerFade = LinearGradient(
        colors: [AppColors.paleViolet.opacity(0.28), .clear],
        startPoint: .top,
        endPoint: .bottom
    )

    /// Focus ring gradient.
    static let focusRing = AngularGradient(
        colors: [AppColors.lavender, AppColors.lilac, AppColors.lavender],
        center: .center
    )

    /// Break ring gradient.
    static let breakRing = AngularGradient(
        colors: [
            AppColors.breakTint,
            AppColors.breakTint.opacity(0.65),
            AppColors.breakTint
        ],
        center: .center
    )
}
