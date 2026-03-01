# PomoDuo Accessibility

**Last updated:** February 2026

PomoDuo is designed to be usable by everyone. Every screen, control, and animation in the app has been built with Apple's accessibility frameworks and tested against the nine categories in the App Store's Accessibility Nutrition Labels.

## Nutrition Label Summary

| Feature | Status | Notes |
|---|---|---|
| **VoiceOver** | Fully supported | Custom labels, hints, traits, and element grouping on all screens. |
| **Voice Control** | Fully supported | All interactive controls are labeled; high-traffic buttons have short spoken alternatives via `accessibilityInputLabels`. |
| **Larger Text** | Fully supported | All text uses Dynamic Type. Layouts adapt without truncation at the largest accessibility sizes. |
| **Dark Interface** | Fully supported | All surfaces, labels, and gradients respond to Light/Dark appearance via trait-adaptive colors. |
| **Sufficient Contrast** | Fully supported | Brand colors automatically shift to higher-contrast variants when the Increase Contrast setting is enabled, meeting WCAG 2.1 AA (4.5:1 for normal text, 3:1 for large text and icons). |
| **Differentiate Without Color** | Fully supported | Anywhere color is the primary differentiator, a secondary visual cue (icon, shape, or symbol) appears when the Differentiate Without Color setting is on. |
| **Reduce Motion** | Fully supported | All animations, transitions, and pulsing effects are suppressed when Reduce Motion is enabled. The app also disables cosmetic animations in Low Power Mode. |
| **Closed Captions** | Not applicable | PomoDuo contains no video or pre-recorded audio content. |
| **Audio Descriptions** | Not applicable | PomoDuo contains no video content. |

## VoiceOver

Every view provides descriptive accessibility labels and hints:

- **Timer screen** -- the circular progress ring, phase label, and time remaining are grouped into a single accessible element with a combined description (e.g., "Focus -- 18 minutes 30 seconds remaining"). Round indicator dots are grouped with the summary "Round 2 of 4."
- **Partner screen** -- pairing status, partner presence, and session controls are each labeled with clear descriptions and hints explaining their actions.
- **History screen** -- the weekly focus chart exposes a computed summary (e.g., "Weekly focus chart: 120 minutes across 5 days") rather than raw data points. Session rows announce type, duration, and timestamp.
- **Settings screen** -- all toggles, pickers, and navigation links carry labels that match their visible text.

Decorative elements (icons used purely for visual embellishment) are marked `accessibilityHidden(true)` so VoiceOver skips them.

## Voice Control

All interactive controls have visible text labels that Voice Control can match. For controls with multi-word labels, `.accessibilityInputLabels` provides shorter spoken alternatives so users can activate them with fewer words:

| Screen | Control | Spoken alternatives |
|---|---|---|
| Timer | Start Focus | "Start", "Begin", "Go" |
| Timer | Stop | "End" |
| Timer | Resume | "Play", "Continue" |
| Timer | Skip | "Next" |
| Timer | Continue | "Next", "Done" |
| Partner (unpaired) | Generate Pairing Code | "Generate", "Code" |
| Partner (unpaired) | Enter Partner's Code | "Enter Code", "Enter" |
| Partner (paired) | Start Session | "Start", "Begin" |
| Partner (paired) | Disconnect | "Unpair", "Remove" |
| Code entry | Connect | "Join", "Pair" |
| Session request | Accept | "Yes", "OK" |
| Session request | Decline | "No", "Reject" |
| Active session | End Session | "End", "Stop" |
| Active session | Skip to Break | "Skip", "Break" |
| Active session | Next Round | "Next", "Continue" |
| Settings | Sign Out | "Logout", "Exit" |
| Settings | Delete Account | "Delete" |
| App Blocking | Enable App Blocking | "Enable", "Block" |
| App Blocking | Choose Apps to Block | "Choose Apps", "Select" |
| App Blocking | Clear Selection | "Clear", "Reset" |

## Larger Text & Dynamic Type

- All text in the app uses semantic fonts (`.title`, `.title2`, `.headline`, `.body`, `.subheadline`, `.caption`, `.caption2`) or the scalable `.largeTitle` style. No fixed-point font sizes are used for user-facing text.
- Layouts use flexible stacks and `Spacer` to reflow gracefully at the five largest accessibility text sizes (AX1 through AX5).
- The launch screen icon uses `.largeTitle` so it scales with the user's preferred text size.

## Dark Interface

PomoDuo fully supports Dark Mode:

- **Surface colors** (`surface`, `surfaceSecondary`) resolve to dark-appropriate backgrounds automatically using `UIColor { traitCollection in ... }`.
- **Text colors** (`secondaryLabel`) adapt to maintain readability on both light and dark backgrounds.
- **Gradients** (banner, bannerFade) switch palette based on `colorScheme` so they remain visible and attractive in both appearances.
- All five brand colors (lavender, lilac, success, pauseTint, stopTint) resolve correctly in both Light and Dark Mode.

## Sufficient Contrast (Increase Contrast)

When the user enables **Settings > Accessibility > Display & Text Size > Increase Contrast**, PomoDuo's five brand/semantic colors shift to higher-saturation or higher-luminance variants that meet WCAG 2.1 AA contrast ratios against their respective backgrounds:

| Color | Standard | Light + High Contrast | Dark + High Contrast |
|---|---|---|---|
| Lavender | `(0.56, 0.44, 0.86)` | `(0.46, 0.34, 0.76)` | `(0.66, 0.54, 0.96)` |
| Lilac | `(0.64, 0.52, 0.88)` | `(0.50, 0.36, 0.76)` | `(0.80, 0.68, 0.98)` |
| Success | `(0.35, 0.65, 0.45)` | `(0.22, 0.48, 0.30)` | `(0.55, 0.83, 0.64)` |
| Pause tint | `(0.75, 0.58, 0.27)` | `(0.58, 0.40, 0.10)` | `(0.95, 0.78, 0.48)` |
| Stop tint | `(0.82, 0.34, 0.37)` | `(0.72, 0.24, 0.28)` | `(0.92, 0.44, 0.48)` |

All high-contrast variants are verified by automated tests to achieve a minimum 4.5:1 contrast ratio (WCAG AA for normal text).

## Differentiate Without Color

Two UI elements previously relied on color as the sole differentiator. When **Settings > Accessibility > Display & Text Size > Differentiate Without Color** is enabled:

- **Focus streak chart** -- stacked solo and paired bar segments display small overlay icons (a single-person icon for solo minutes, a two-person icon for paired minutes) so the series are distinguishable without relying on color.
- **Partner presence indicator** -- the partner's online/offline status dot gains an exclamation mark ("!") overlay when the partner is offline, providing a shape cue in addition to the green/orange color change.

All other color-coded elements in the app already use secondary cues (text labels, distinct icons, or position) and require no additional treatment.

## Reduce Motion

Every animation in the app reads `@Environment(\.accessibilityReduceMotion)`:

- **Timer controls** -- state transitions (idle, active, paused, completed) use `.opacity` instead of `.scale`, `.move`, or `.spring` transitions.
- **Round indicator dots** -- the pulsing ring around the current round is suppressed entirely; scale effects and completion pop animations are disabled.
- **Focus streak chart** -- the filter-switch animation between All/Solo/Paired tabs is replaced with an instant cut.
- **Launch screen** -- the brain icon entrance animation is disabled.
- **Low Power Mode** -- cosmetic looping animations (e.g., the current-round pulse) are also suppressed when the device is in Low Power Mode, independent of the Reduce Motion setting.

## Testing

Accessibility behavior is covered by automated tests:

- **17 adaptive color tests** verify that all brand and surface colors resolve to the correct values for every combination of Light/Dark appearance and standard/high contrast.
- **10 WCAG AA contrast tests** verify that high-contrast color variants meet the 4.5:1 minimum ratio against their expected backgrounds.
- All 319 tests in the test suite pass with the current implementation.

## Contact

If you have questions or feedback about PomoDuo's accessibility, please contact us at arieltyson30190@gmail.com.
