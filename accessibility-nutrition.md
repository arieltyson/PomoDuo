# PomoDuo Accessibility Audit

Accessibility Nutrition Labels evaluation for App Store Connect submission. This document audits PomoDuo against Apple's nine accessibility features and identifies what's ready, what needs work, and what doesn't apply.

---

## Common Tasks Checklist

Before evaluating each feature, here are PomoDuo's common tasks — the primary functionality users must be able to complete:

| # | Common Task | Screens Involved |
|---|-------------|-----------------|
| 1 | **Start a solo focus session** | Timer tab (idle state) |
| 2 | **Pause, resume, and stop a running timer** | Timer tab (active state) |
| 3 | **Complete a full Pomodoro cycle** (focus → break → focus) | Timer tab |
| 4 | **Pair with a study partner** (generate code, enter code) | Partner tab → Pairing flow |
| 5 | **Accept/decline an incoming session request** | Partner tab → Incoming request sheet |
| 6 | **Run a paired focus session** (with partner presence) | Partner tab → Active paired session |
| 7 | **View focus history and weekly chart** | History tab |
| 8 | **Adjust timer settings** (durations, rounds) | Settings → Timer Settings |
| 9 | **Configure app blocking** (Screen Time) | Settings → App Blocking |
| 10 | **Manage notifications** | Settings → Notification Preferences |
| 11 | **Sign in with Apple / manage account** | Settings → Account |
| 12 | **Complete onboarding** | First launch experience |
| 13 | **Interact with Live Activity** (pause/resume from Lock Screen) | Dynamic Island / Lock Screen |
| 14 | **Change appearance** (system/light/dark) | Settings |
| 15 | **Submit feedback** | Settings → Feedback |

---

## Feature-by-Feature Evaluation

### 1. VoiceOver

**Can users complete all common tasks using VoiceOver?**

**Current State: Mostly Ready**

**What's Done:**
- Custom `AccessibilityAnnouncer` system posts `AccessibilityNotification.Announcement` for all timer state changes (start, pause, resume, round complete, break started, focus resumed, stop) and all paired session events (request sent, incoming request, focus began, pause, resume, break, completed, ended)
- `CircularProgressView` — `.accessibilityElement(children: .ignore)`, dynamic `.accessibilityLabel("Focus timer" / "Break timer")`, `.accessibilityValue(timeString)`, `.accessibilityAddTraits(.updatesFrequently)`
- `SessionHeaderView` — `.accessibilityElement(children: .ignore)`, `.accessibilityLabel("phase, round X of Y")`, `.accessibilityAddTraits(.isHeader)`, decorative icon `.accessibilityHidden(true)`
- `RoundIndicatorView` — `.accessibilityElement(children: .ignore)`, `.accessibilityLabel("Round X of Y")`
- `TimerControlsView` — All buttons (Start, Pause, Resume, Stop, Skip, Continue) have `.accessibilityHint()` explaining their action
- `TimerView` — `.accessibilityActions` block provides pause, resume, stop, continue actions directly on the timer progress ring
- `ActivePairedSessionView` — `PartnerBannerView` uses `.accessibilityElement(children: .combine)` with label "Studying with NAME, active/offline"; `SessionPhaseBadge` marked as `.isHeader`; `PairedCountdownView` labeled; `PairedRoundProgress` combined
- `IncomingSessionRequestView` — Heading marked `.isHeader`, Accept/Decline have `.accessibilityHint()`, decorative illustration `.accessibilityHidden(true)`, `AccessibilityAnnouncer.announceIncomingSessionRequest()` fires on appear
- `WaitingForPartnerView` — Pairing code card uses `.accessibilityLabel("Pairing code X X X X X X")` with spaced digits
- `SessionRowView` (History) — `.accessibilityElement(children: .combine)`, `.accessibilityLabel("SOLO/PAIRED focus, X minutes, round Y of Z")`
- `FocusStreakChartView` — Each bar has `.accessibilityLabel("DAY: X solo/paired minutes")`; entire chart has `.accessibilityElement(children: .combine)` with weekly summary
- `NotificationPreferencesView` — `.accessibilityElement(children: .combine)` with "Notifications ENABLED/DISABLED"
- `SignInWithAppleButtonView` — `.accessibilityLabel()` set per style
- `FeedbackView` — Field `.accessibilityLabel(category.accessibilityFieldLabel)`, confirmation `.accessibilityLabel("Feedback copied")`
- `ConnectionStatusBanner` — `.accessibilityAddTraits(.updatesFrequently)`
- Dynamic Island / Live Activity — comprehensive coverage: `ClockStatusIconView`, `CompactCountdownValueView`, `MinimalView`, `ExpandedLeadingView`, `ExpandedCenterView`, `ExpandedTrailingView` all have appropriate `.accessibilityLabel()`, `.accessibilityValue()`, `.accessibilityAddTraits()`, and `.accessibilityHidden(true)` on decorative icons
- 28 test cases in `AccessibilityTests.swift` covering announcer, circular progress labels, and reduced motion

**Gaps to Address:**
- `OnboardingView` — No explicit `.accessibilityLabel()` or `.accessibilityHint()` on onboarding step cards. Users can still navigate (buttons are standard SwiftUI), but step content isn't semantically grouped
- `CodeEntrySheet` — No `.accessibilityHint()` on the "Connect" button
- `PairedPartnerView` — Missing accessibility labels on partner info and "Start Session" / "Disconnect" buttons
- `AccountView` — No explicit accessibility modifiers detected
- `TimerSettingsView` — No hints on duration/round pickers (standard controls, but hints would improve discovery)
- `AppBlockingView` — Minimal; only the decorative icon is hidden
- `SettingsView` — Partial; appearance picker and rate button have hints, but other navigation links don't

**Verdict: Can indicate support once gaps are addressed.** Core timer and pairing flows are excellent. Settings and onboarding need enhancement.

---

### 2. Voice Control

**Can users navigate and interact using voice to tap, swipe, click, and type?**

**Current State: Ready**

**What's Done:**
- All interactive elements use standard SwiftUI `Button`, `Picker`, `Toggle`, `TextField`, `NavigationLink`, `ShareLink` — all natively support Voice Control
- No `.onTapGesture` used on primary interactions
- No `.onLongPressGesture` for critical functions
- No drag-and-drop interactions
- No custom gesture recognizers
- No `UIViewRepresentable` or `UIViewControllerRepresentable` wrappers that bypass accessibility
- `TimerView` provides `.accessibilityActions` block (pause, resume, stop, continue) — accessible to Voice Control
- `CodeEntrySheet` — Standard `TextField` with `.accessibilityLabel("Pairing code")`
- All buttons have visible text labels that Voice Control can target
- App Intents (`StartFocusIntent`, `CheckFocusStatsIntent`) provide Siri/Shortcuts integration
- Live Activity uses `AppIntent` buttons (TogglePauseIntent, StopTimerIntent) — compatible

**Gaps to Address:**
- Consider adding `.accessibilityInputLabels()` to some controls for alternative Voice Control command names (nice-to-have, not required)

**Verdict: Can indicate support.** The app uses standard SwiftUI controls throughout with no custom gestures blocking Voice Control.

---

### 3. Larger Text

**Does text scale to 200% or more using Dynamic Type?**

**Current State: Mostly Ready**

**What's Done:**
- 72+ instances of relative text styles (`.body`, `.title`, `.title2`, `.title3`, `.headline`, `.subheadline`, `.caption`, `.caption2`, `.largeTitle`) that automatically scale with Dynamic Type
- Standard SwiftUI `List`, `Form`, and `ScrollView` containers handle overflow at large sizes
- Live Activity countdown text uses `.minimumScaleFactor(0.8)` and `.minimumScaleFactor(0.7)` to prevent clipping
- No `@ScaledMetric` needed — layout is flexible with standard SwiftUI primitives
- All fixed `.frame()` dimensions are for images/icons/avatars, not text containers

**Fixed Font Sizes (Won't Scale):**

| File | Size | Context | Severity |
|------|------|---------|----------|
| `PomoDuoLiveActivity.swift:285` | 14pt | Icon in widget | Low |
| `LaunchAnimationView.swift:51` | 34pt | Splash screen icon | Low |
| `RoundIndicatorView.swift:57` | 5pt | Decorative dot | Negligible |
| `IncomingSessionRequestView.swift:72` | 52pt | Illustration icon | Medium |
| `ActivePairedSessionView.swift:755` | 6pt | Decorative dot | Negligible |

**Live Activity Truncation Risk:**
- `PomoDuoLiveActivity.swift:343` — `.font(.headline)` with `.lineLimit(1)` but no `.minimumScaleFactor()` on phase label
- `PomoDuoLiveActivity.swift:350` — `.font(.caption2)` with `.lineLimit(1)` but no `.minimumScaleFactor()` on round indicator

**Gaps to Address:**
- Add `.minimumScaleFactor()` to Live Activity phase label and round indicator (lines 343, 350)
- Replace `IncomingSessionRequestView` icon size 52 with `.largeTitle` or similar relative style
- Replace `LaunchAnimationView` icon size 34 with `.title` (low priority — splash screen)

**Verdict: Can indicate support once Live Activity truncation is fixed.** The main app fully supports Dynamic Type. Widget needs minor fixes.

---

### 4. Dark Interface

**Does the app apply a dark color scheme to screens, menus, and controls?**

**Current State: Partially Ready**

**What's Done:**
- `AppearanceManager` with three-way preference: System / Light / Dark
- `.preferredColorScheme(appearanceManager.preferredColorScheme)` applied at the root `PomoDuoApp`
- SwiftUI system colors (`.primary`, `.secondary`, `.tertiary`) used in many places — adapt automatically
- Material backgrounds (`.thinMaterial`, `.regularMaterial`) adapt correctly
- `SignInWithAppleButtonView` checks `@Environment(\.colorScheme)` to swap foreground colors

**Issues:**

| Issue | File | Severity |
|-------|------|----------|
| `AppColors.surface = Color.white` — hardcoded, won't adapt | `AppColors.swift:27` | High |
| `AppColors.surfaceSecondary` — hardcoded light color | `AppColors.swift:29` | High |
| Hardcoded `.foregroundStyle(.white)` on colored backgrounds | Multiple files (~10 instances) | Medium |
| No dark variants in color asset catalog (`AccentColor` only) | `Assets.xcassets` | Medium |
| Gradients (`AppGradients.swift`) use fixed colors, may have poor contrast in dark mode | `AppGradients.swift` | Medium |
| Live Activity uses hardcoded `.white` text throughout | `PomoDuoLiveActivity.swift` | Medium |
| Only 1 file checks `@Environment(\.colorScheme)` | App-wide | High |

**Hardcoded `.white` foreground instances found in:**
- `OnboardingView.swift` — white text on lavender
- `ConnectionStatusBanner.swift` — white on orange
- `SessionHeaderView.swift` — white on gradient banner
- `ActivePairedSessionView.swift` — white on colored surfaces
- `PairedPartnerView.swift` — white elements
- `SettingsView.swift` — white text
- `RoundIndicatorView.swift` / `CircularProgressView.swift` — white elements
- `PomoDuoLiveActivity.swift` — multiple white text instances

**What Needs to Be Done:**
1. Make `AppColors.surface` and `AppColors.surfaceSecondary` color-scheme-aware (return dark backgrounds in dark mode)
2. Audit all hardcoded `.white` and `.black` usage — replace with adaptive colors or add `@Environment(\.colorScheme)` conditionals
3. Add dark mode color variants to `AppColors` (either via asset catalog color sets or in-code conditionals)
4. Update `AppGradients` with dark mode variants for sufficient contrast
5. Update Live Activity colors to adapt to device appearance
6. Test all screens in dark mode systematically

**Verdict: Cannot indicate support yet.** The preference system works, but `AppColors.surface = Color.white` and widespread hardcoded white text mean the dark mode experience is inconsistent. Requires a color system overhaul.

---

### 5. Differentiate Without Color Alone

**Does the app use shapes or text, in addition to or instead of color, to distinguish key information?**

**Current State: Partially Ready**

**What's Done:**
- Session phase badges: Text label + SF Symbol icon + color (three indicators)
- Session type in history: Different SF Symbols (`person.fill` vs `person.2.fill`) + color
- Timer completion state: Checkmark icon + "Continue" text + success tint
- Paused indicator: "Paused" text label + colored dot
- Round progress dots: Completed rounds show checkmark overlay (not just color change)
- Current round: Pulsing ring animation (visual distinction beyond color)
- App blocking indicators use Label with icon + text

**Issues:**
- `@Environment(\.accessibilityDifferentiateWithoutColor)` is **never checked** anywhere in the codebase
- Partner presence indicator (`ActivePairedSessionView.swift:417-443`): Uses green/orange dots. Does include text ("Active"/"Offline?") but color-blind users may struggle with the small colored dot
- Upcoming round dots in `RoundIndicatorView`: Rely solely on opacity/color to differentiate from completed dots (no shape change)
- `FocusStreakChartView`: Solo vs. paired bars are differentiated only by color gradient (lavender vs. lilac) — no pattern or shape distinction
- `FeedbackCategory`: Bug = red, Feature = yellow — color-only differentiation in UI

**What Needs to Be Done:**
1. Add `@Environment(\.accessibilityDifferentiateWithoutColor)` checks and provide alternate visual indicators (shapes, patterns, icons) when active
2. Add patterns or distinct shapes to chart bars to differentiate solo vs. paired sessions
3. Add shape distinction to upcoming vs. completed round indicator dots (e.g., open circle vs. filled)
4. Add icons alongside color in feedback category badges

**Verdict: Cannot indicate support yet.** Many information-bearing elements use text + icon + color (good), but the chart, round indicators, and feedback categories rely on color alone in important contexts. The `accessibilityDifferentiateWithoutColor` environment variable is never consulted.

---

### 6. Sufficient Contrast

**Does the app increase or adjust contrast between text/iconography and background?**

**Current State: Partially Ready**

**What's Done:**
- `AppColors.secondaryLabel` (RGB 0.42, 0.40, 0.50) on white — passes WCAG AA for normal text
- System colors (`.primary`, `.secondary`) used in most text — proper contrast
- Material backgrounds provide proper contrast

**Issues:**
- `@Environment(\.accessibilityIncreaseContrast)` / `isAccessibilityIncreaseContrast` is **never checked** anywhere in the codebase
- `AppColors.lavender` (RGB 0.56, 0.44, 0.86) on white background — estimated contrast ratio ~3.2:1, **fails WCAG AA** (requires 4.5:1 for normal text, 3:1 for large text)
- `AppColors.paleViolet` (RGB 0.85, 0.76, 0.97) on white — very low contrast, **fails WCAG AA**
- `AppColors.lilac` (RGB 0.73, 0.60, 0.93) — borderline
- White text on colored banner gradients — contrast depends on specific gradient point
- White text on orange connection status banner — should be verified
- No high-contrast color variants exist for any brand colors

**What Needs to Be Done:**
1. Audit all text-on-background combinations with a contrast checker tool (WCAG 2.1 AA: 4.5:1 normal text, 3:1 large text)
2. Darken `AppColors.lavender` for text usage or use it only for large text/icons where 3:1 is acceptable
3. Never use `AppColors.paleViolet` for text on white
4. Add `@Environment(\.accessibilityIncreaseContrast)` support to provide higher-contrast alternatives
5. Verify white-on-color combinations (banners, badges, buttons)

**Verdict: Cannot indicate support yet.** Brand lavender likely fails WCAG AA for normal text on white. No increased contrast support is implemented.

---

### 7. Reduced Motion

**Does the app modify or reduce animations that may cause motion sickness?**

**Current State: Mostly Ready**

**What's Done:**
- Custom `ReducedMotionModifier` provides `motionSensitiveAnimation()` extension with automatic degradation
- 24 locations properly check `@Environment(\.accessibilityReduceMotion)`
- Power state awareness — many animations also check `isLowPowerModeEnabled`

**Animations with Proper Reduce Motion Support:**

| Animation | File | Behavior with Reduce Motion |
|-----------|------|---------------------------|
| Launch sequence | `LaunchAnimationView.swift` | Skips animation, shows brand briefly |
| Pause breathing pulse | `SessionTransitionEffects.swift` | Static, no repeating animation |
| Resume glow flash | `SessionTransitionEffects.swift` | Disabled entirely |
| Celebration particles | `SessionTransitionEffects.swift` | Burst disabled |
| Phase transition | `SessionTransitionEffects.swift` | Opacity-only, no spring |
| Round completion pop | `SessionTransitionEffects.swift` | Jumps to final state |
| Timer progress ring | `CircularProgressView.swift` | `.none` animation |
| Paused dot pulse | `CircularProgressView.swift` | Static opacity |
| Round dot scale | `RoundIndicatorView.swift` | `.none` animation |
| Checkmark transition | `RoundIndicatorView.swift` | Opacity-only |
| Current round pulse | `RoundIndicatorView.swift` | Static |
| Button state transitions | `TimerControlsView.swift` | Opacity-only |
| Skeleton shimmer | `SkeletonTabView.swift` | Overlay hidden entirely |
| Paired session state changes | `ActivePairedSessionView.swift` | `.none` animation |
| Live Activity symbol pulse | `PomoDuoLiveActivity.swift` | Respects reduce motion |

**Issues (Animations That Ignore Reduce Motion):**

| Issue | File | Severity |
|-------|------|----------|
| `.symbolEffect(.bounce, value: phaseName)` — always plays | `SessionHeaderView.swift:39` | Medium |
| `.symbolEffect(.pulse, options: .repeating)` — always plays | `IncomingSessionRequestView.swift:74` | High (continuous) |
| `.animation(.default, value: filter)` — no reduce motion check | `FocusStreakChartView.swift:104` | Low |
| `.animation(.easeInOut(duration: 0.35), value: launchPhase)` — structural transition | `RootView.swift:63` | Low (one-time) |
| `.move(edge: .top).opacity` transition — no reduce motion check | `ConnectionStatusBanner.swift:20` | Low |

**What Needs to Be Done:**
1. Fix `IncomingSessionRequestView.swift:74` — add `isActive: !reduceMotion` to the `.symbolEffect(.pulse)` (High priority — continuous repeating animation)
2. Fix `SessionHeaderView.swift:39` — add `isActive: !reduceMotion` condition to `.symbolEffect(.bounce)` (Medium)
3. Add reduce motion check to `FocusStreakChartView.swift:104` chart animation (Low)

**Verdict: Can indicate support once the two symbolEffect issues are fixed.** The app has excellent reduce motion infrastructure — only 2-3 animations slipped through.

---

### 8. Captions

**Can users follow dialogue and relevant sounds with time-synchronized text?**

**Current State: Not Applicable**

PomoDuo does not contain video or audio-only content. There is no media playback, no instructional videos, no audio narration, and no video-based onboarding. The app is entirely UI-driven with text and visual elements.

**Verdict: Not applicable — no action needed.** If video content (e.g., onboarding tutorial, marketing preview) is added in the future, captions would need to be provided.

---

### 9. Audio Descriptions

**Can users hear audio descriptions of video content?**

**Current State: Not Applicable**

Same as Captions — PomoDuo has no video content that would require audio descriptions.

**Verdict: Not applicable — no action needed.**

---

## Summary Matrix

| Feature | Status | Can Indicate Support? | Work Required |
|---------|--------|----------------------|---------------|
| **VoiceOver** | Mostly Ready | After fixes | Add labels to onboarding, settings gaps, partner view |
| **Voice Control** | Ready | Yes | Minor polish (input labels) |
| **Larger Text** | Mostly Ready | After fixes | Fix Live Activity truncation, replace 2 fixed font sizes |
| **Dark Interface** | Partially Ready | No | Color system overhaul, remove hardcoded white, add dark variants |
| **Differentiate Without Color Alone** | Partially Ready | No | Add `differentiateWithoutColor` checks, fix chart, round dots |
| **Sufficient Contrast** | Partially Ready | No | Contrast audit, darken lavender for text, add increase contrast support |
| **Reduced Motion** | Mostly Ready | After fixes | Fix 2 symbolEffect animations |
| **Captions** | N/A | N/A | None (no video content) |
| **Audio Descriptions** | N/A | N/A | None (no video content) |

---

## Priority Action Plan

### Phase 1 — Quick Wins (Can Ship Now)

These are small, targeted fixes that unblock feature claims:

**Reduced Motion (2 fixes):**
- [ ] `IncomingSessionRequestView.swift:74` — Wrap `.symbolEffect(.pulse)` with `isActive: !reduceMotion`
- [ ] `SessionHeaderView.swift:39` — Add `isActive: !reduceMotion` to `.symbolEffect(.bounce)`

**Larger Text (2 fixes):**
- [ ] `PomoDuoLiveActivity.swift:343` — Add `.minimumScaleFactor(0.7)` to phase label
- [ ] `PomoDuoLiveActivity.swift:350` — Add `.minimumScaleFactor(0.7)` to round indicator

**VoiceOver (5 fixes):**
- [ ] `OnboardingView.swift` — Add `.accessibilityLabel()` and `.accessibilityHint()` to step cards
- [ ] `CodeEntrySheet.swift` — Add `.accessibilityHint("Connects to your partner using the entered code.")` to Connect button
- [ ] `PairedPartnerView.swift` — Add labels to partner info, Start Session, Disconnect buttons
- [ ] `AccountView.swift` — Add accessibility modifiers to sign-in and account state elements
- [ ] `TimerSettingsView.swift` — Add `.accessibilityHint()` to duration pickers

### Phase 2 — Color System Overhaul (Blocks 3 Features)

This is the largest workstream and blocks Dark Interface, Differentiate Without Color Alone, and Sufficient Contrast.

**Dark Interface:**
- [ ] Refactor `AppColors` to use color-scheme-aware definitions (either asset catalog color sets or `@Environment(\.colorScheme)` conditionals)
- [ ] Replace `AppColors.surface = Color.white` with an adaptive surface color
- [ ] Replace `AppColors.surfaceSecondary` with an adaptive variant
- [ ] Audit and fix all ~10 hardcoded `.foregroundStyle(.white)` instances
- [ ] Update `AppGradients` with dark mode variants
- [ ] Update Live Activity colors to be appearance-adaptive
- [ ] Test every screen in dark mode

**Sufficient Contrast:**
- [ ] Run all text-on-background combinations through a WCAG contrast checker
- [ ] Darken `AppColors.lavender` for text contexts or restrict to large text/icon use
- [ ] Never use `AppColors.paleViolet` as text color on light backgrounds
- [ ] Add `@Environment(\.accessibilityIncreaseContrast)` support with higher-contrast color alternatives
- [ ] Verify white-on-color combinations (banners, badges, buttons) meet 4.5:1 or 3:1

**Differentiate Without Color Alone:**
- [ ] Add `@Environment(\.accessibilityDifferentiateWithoutColor)` checks where color conveys meaning
- [ ] Add patterns or distinct shapes to `FocusStreakChartView` bars (solo vs. paired)
- [ ] Add shape distinction to `RoundIndicatorView` (upcoming vs. completed — e.g., open circle vs. filled + checkmark)
- [ ] Add icons alongside color in `FeedbackCategory` badges

### Phase 3 — Polish

- [ ] Add `.accessibilityInputLabels()` to key controls for Voice Control alternative naming
- [ ] Replace fixed icon font sizes with relative styles (`IncomingSessionRequestView:72`, `LaunchAnimationView:51`)
- [ ] Add reduce motion check to `FocusStreakChartView.swift:104` chart animation
- [ ] Add reduce motion check to `ConnectionStatusBanner.swift:20` transition

---

## Testing Recommendations

Before claiming support in App Store Connect, test each feature with a physical device:

1. **VoiceOver** — Navigate all common tasks eyes-free. Verify announcements fire at correct moments. Ensure no unlabeled buttons or missing context.
2. **Voice Control** — Enable Voice Control, say "Show names" to see labels. Verify all buttons/controls are targetable by voice.
3. **Larger Text** — Set Accessibility > Display & Text Size > Larger Text to maximum. Walk through all screens — no text should be clipped or unreadable.
4. **Dark Interface** — Enable dark mode. Every screen should have appropriate contrast and no white backgrounds bleeding through.
5. **Differentiate Without Color Alone** — Enable Settings > Accessibility > Display & Text Size > Differentiate Without Color. Verify all status indicators, charts, and round dots are distinguishable without color.
6. **Sufficient Contrast** — Enable Settings > Accessibility > Display & Text Size > Increase Contrast. Verify all text meets WCAG AA (4.5:1 normal, 3:1 large).
7. **Reduced Motion** — Enable Settings > Accessibility > Motion > Reduce Motion. Walk through all flows — no motion-intensive animations should play.

---

## Accessibility URL

Consider providing an accessibility URL on the App Store product page that links to a page covering:
- Supported accessibility features and how they work in PomoDuo
- How to configure in-app accessibility settings (appearance, notifications)
- Languages supported
- Known limitations (e.g., Shield extension has limited customization)
- Contact for accessibility feedback
