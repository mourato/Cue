# ADR 078: Use a sidebar for Preferences navigation

- Status: Accepted
- Date: 2026-09-07

## Context

Cue's Settings window grouped its destinations in a SwiftUI `TabView`. The
number of destinations and the optional Screen Recording destination make a
persistent sidebar easier to scan and keep visible while configuring settings.

## Decision

Use SwiftUI `NavigationSplitView` with a native sidebar `List` for
`PreferencesView`. Keep `PreferencesTab` and the `preferences.selectedTab`
UserDefaults key as compatibility interfaces for programmatic selection,
restoration, and `cue://settings?tab=` deep links.

## Consequences

Settings destinations remain side by side with their content, and the selected
destination remains visible while navigating. The existing settings views,
localization, and compile-time Video-module gating remain unchanged.

## Rejected or deferred

The existing `TabView` was not retained because it hides the navigation context
when a destination is open. No custom sidebar component or external navigation
library is needed.

## References and license

Apple's [NavigationSplitView documentation](https://developer.apple.com/documentation/swiftui/navigationsplitview)
is used as platform guidance. Cue independently reimplements the pattern with
SwiftUI; no Apple source code or assets are copied.

## Affected surfaces

- `Cue/Features/Preferences/PreferencesView.swift`
- Settings documentation and the Preferences navigation contract
