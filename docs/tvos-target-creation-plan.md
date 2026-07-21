# tvOS "Octopus Explorer" — Target Creation Plan (Phase 2 pre-work)

Status: **Target created; M1 empty scaffold and M2 nav shell are done; M3 is underway.**
This document started as the decision record + implementation spec produced by the
tech-architect pass on 2026-07-19 (branch `feature/tvos-octopus-explorer-prework`).
It now tracks implementation against that plan on `feature/tvos-target-scaffold`.
As of 2026-07-21, M3 slice 1 has real tvOS main-tab content surfaces for Discover,
Requests, Watchlist, and Profile, and M3 slice 2 has real movie/TV Media Detail
plus create-request flow. M3 slice 3 replaced the first-run placeholders with a
real server setup screen plus Local/Jellyfin login. Search, interactive Plex login,
and tvOS UI tests remain open.

---

## 0. project.yml / XcodeGen decision (Item 1) — RESOLVED: abandon XcodeGen

**Decision:** Treat `project.yml` as stale/abandoned (option b). Continue direct
`SeerrClient.xcodeproj/project.pbxproj` edits, including for the tvOS target.
`project.yml` was marked with a prominent STALE banner (commit `bee0bd1`) rather
than deleted, so history is preserved and nobody regenerates from it by accident.

**Why not reconcile-and-regenerate (option a):** a `xcodegen generate` from the
current spec is not just churn — it is actively destructive:

1. **Reverts the rebrand.** `project.yml` still declares `bundleIdPrefix:
   com.rodrigoindustries` and `PRODUCT_BUNDLE_IDENTIFIER: com.rodrigoindustries.SeerrClient`.
   The merged `.pbxproj` reality is `com.frostforgelabs.OctopusExplorer`. A regen
   would silently undo the shipped Octopus Explorer rename.
2. **Deletes a target.** The spec lists only `SeerrClient` + `SeerrClientTests`.
   The real project also has `SeerrClientUITests` — a regen drops it entirely.
3. **Drops hand-tuned build settings** (this is the ~266-line "unrelated churn"
   observed in the watchlist-refactor session). The `.pbxproj` carries, and the
   spec does not encode: `DEVELOPMENT_TEAM`, `CODE_SIGN_IDENTITY`, every
   `INFOPLIST_KEY_*` (FaceID usage string, `UILaunchStoryboardName`, supported
   orientations, `CFBundleDisplayName`), `LD_RUNPATH_SEARCH_PATHS`, the
   `TEST_HOST` / `BUNDLE_LOADER` / `TEST_TARGET_NAME` wiring, and the full
   CLANG/GCC warning block. XcodeGen replaces all of these with its own defaults,
   and re-mints every object UUID, so even unchanged settings render as a large
   diff.
4. **Clobbers the shared scheme.** `SeerrClient.xcscheme` is not declared in the
   spec, so a regen deletes it (the other half of the prior revert).

Reconciling the spec well enough to round-trip cleanly would mean re-encoding all
of the above plus keeping it in lockstep on every future direct edit — a
maintenance burden wildly disproportionate to the goal (adding one target). The
`.pbxproj` is well hand-maintained and is the de-facto source of truth.

---

## 1. Target name + bundle ID (Item 2.1) — driven by the ASC finding (Item 2.3)

| Attribute | Value | Rationale |
|---|---|---|
| **PRODUCT_BUNDLE_IDENTIFIER** | `com.frostforgelabs.OctopusExplorer` — **SAME as the iOS app** | Required to share ONE App Store Connect record / Universal Purchase (see §3). A distinct `...TV` ID would force a *separate* app record. |
| **Xcode target name (internal)** | `SeerrClientTV` | Two targets can't share a name; extends the established "internal names stay SeerrClient" convention (iOS target is internally `SeerrClient` despite the "Octopus Explorer" brand). |
| **Product / display name** | "Octopus Explorer" via `INFOPLIST_KEY_CFBundleDisplayName` / `CFBundleName` | Same public brand as iOS. |
| **SDKROOT / platform** | `appletvos` | tvOS target. |
| **Deployment target** | tvOS 18 (match the iOS 18 floor; tvOS 16+ minimum required for `ASWebAuthenticationSession`, `.searchable`, `.refreshable` used below) | Consistent floor. |

> The STEPS.md placeholder `com.frostforgelabs.OctopusExplorerTV` is **rejected** —
> see §3. Same bundle ID, separate target.

## 2. Shared-vs-tvOS code split (Item 2.2) — grounded in the real tree

Architecture is clean MVVM + Repository, zero third-party deps. `project.pbxproj`
is classic (objectVersion 77, per-file `PBXBuildFile`/`PBXFileReference`, **not**
`PBXFileSystemSynchronizedRootGroup`), so each shared file added to the tvOS target
is one new `PBXBuildFile` row + a Sources-phase entry pointing at the existing
`fileRef`.

**Target-membership strategy: shared source group with dual target-membership
checkboxes.** NOT a local Swift Package, NOT a shared framework.
- A local SPM package adds a second build graph and forces `public` access-control
  churn across ~25 currently-internal files (incl. app-level `@Observable`
  singletons referenced from `#Preview`), for zero payoff in a zero-dependency app.
- A framework target adds a third bundle ID + another full build-settings block +
  the same `public` churn. Strictly more pbxproj surgery than dual membership.
- Dual membership is a ~1-line-per-file pbxproj diff and touches no imports or
  access control on the ~30 already-portable files.

**Reusable UNCHANGED (~30 of ~45 non-test files):** all of `Core/Models`,
`Core/Networking` (incl. `TrustManager` → `CommonCrypto`, a system lib on tvOS),
`Core/Storage` (`KeychainManager` → `Security`, works on tvOS), `Core/Utilities`,
`Core/Views/ShimmerView`, every `Features/*/Repositories/*`, every
`Features/*/ViewModels/*` (all `@MainActor` + Observation, **none** import UIKit or
touch orientation/size-class — verified, not assumed), `Core/Navigation/MediaNavDestinations`,
`App/TabSelectionPolicy`.

**Storage runtime caveat:** tvOS Keychain is more likely to be cleared on
app-deletion/reinstall than iOS and lacks the same offload/restore path — plan for
re-login being more frequent on tvOS. `ServerStore` uses `UserDefaults` (portable);
no SwiftData in the codebase, so no on-disk store migration concerns.

**Needs `#if os(tvOS)` / `#if os(iOS)` branching (share the file):**
- `App/ContentView.swift` — `.tabViewStyle(.sidebarAdaptable)` (line ~201) is
  iOS/iPadOS/macOS-only; tvOS uses the default top-tab-bar chrome. Keep the
  `showServerSetup`/`showLogin`/`showMainInterface` decision logic shared; branch
  the `standardMainInterface` tab chrome.
- `App/LaunchAnimationView.swift` — compiles as-is; only needs tvOS size tuning.
- 8 files with `.navigationBarTitleDisplayMode(...)` (iOS-only) — WatchlistView,
  PlexOAuthView, LoginView, MovieDetailView, TvShowDetailView, CollectionDetailView,
  AddServerView, RequestDetailView.
- 6 files with `.navigationBarLeading/.navigationBarTrailing` toolbar placements
  (iOS-only) — prefer switching to cross-platform placements (`.primaryAction`,
  `.cancellationAction`, `.confirmationAction`, `.automatic`) rather than `#if` per site.
- 4 files with `.pickerStyle(.segmented)` (unavailable on tvOS) — AppearanceSection,
  LoginView, RequestListView, WatchlistView.
- 2 files with `.listStyle(.insetGrouped)` (unavailable on tvOS) — ServerListView,
  ProfileView.
- `RequestsTabView` uses `@Environment(\.horizontalSizeClass)`; on tvOS it's always
  `.regular`, so gate the iPad-split branch behind `#if os(iOS)` deliberately rather
  than relying on size-class accident (also see §4 Requests decision).
- All `.refreshable` sites (Discover/Profile/Watchlist/Requests/Search) have no pull
  gesture on tvOS — need a visible remote-driven refresh affordance, not a silent no-op.

**Needs a real tvOS-specific rewrite (not a modifier tweak):**
- `Features/Auth/Views/PlexOAuthView.swift` — imports UIKit and calls
  `UIApplication.shared.open(...)`. Won't compile. tvOS Plex OAuth must use
  `ASWebAuthenticationSession` (available tvOS 16+).
- `.swipeActions` in `RequestListView` and `ServerListView` — no Siri Remote
  equivalent; needs a focus-friendly affordance (context menu / explicit manage mode).

**Entirely NEW tvOS-only files required:**
- A tvOS `Info.plist` (the shared one is hand-pointed via `INFOPLIST_FILE` with
  `GENERATE_INFOPLIST_FILE = NO`; tvOS must not inherit iOS orientation keys or the
  `NSFaceIDUsageDescription` string — tvOS has no biometric hardware, and an unused
  usage string can draw review flags).
- A tvOS launch-image asset set (tvOS does **not** use `LaunchScreen.storyboard`;
  it launches from an Asset-catalog App Icon & Top Shelf image). `LaunchScreen.storyboard`
  must NOT get tvOS target membership.
- A **layered** tvOS app icon (2–5 layers — hard asset-catalog requirement, Xcode
  won't accept a flat single layer for the parallax stack).
- The tvOS views under new `Features/<Feature>/Views-tvOS/` folders (see below).

**Folder layout for tvOS views** (keeps the existing `Features/<Feature>/Views/`
untouched): add sibling `Features/<Feature>/Views-tvOS/` only where a view is
*structurally* different (e.g. focus-driven Discover carousel). Views that need only
a small conditional tweak stay single-file with `#if os(tvOS)`. `App/ContentView`
either branches internally or gets an `App/ContentView+tvOS.swift` extension file
(tvOS-target-only membership).

## 3. App Store Connect implications (Item 2.3) — RESEARCHED, needs user action

**Finding (Apple docs, verified):** a tvOS app for the *same product* is added as a
**platform on the SAME App Store Connect record** as the iOS app, which requires the
tvOS target to use the **same bundle ID** as iOS. Apple's own guidance: *"In the
Xcode project, set the bundle IDs to match the iOS app's bundle ID."* The tvOS build
is uploaded from a **separate Xcode target** and may carry different version/build
strings. Once ≥2 platform versions are approved, the record **automatically becomes
Universal Purchase** — and that is a **one-way door** (a platform can't later be
removed from the record).

- **Same App ID covers both platforms.** Since Xcode 11.4, one App ID
  (`com.frostforgelabs.OctopusExplorer`, already registered for iOS) builds iOS +
  tvOS. **No new App ID registration is required.**
- A distinct `...OctopusExplorerTV` bundle ID would force a **separate** app record,
  separate listing, and separate pricing — only wanted if the TV app were sold
  independently. It is not. → reject the `...TV` suffix.

**What the account owner (user) must do manually — DECISION + ACTION REQUIRED:**
1. **Confirm the Universal Purchase model** (same record, same bundle ID) is desired.
   It's the right call for one free product, but it is **irreversible** once two
   platforms are approved — flagging explicitly.
2. When ready: in App Store Connect, open the existing Octopus Explorer record →
   **Add Platform → tvOS**. (The iOS v1 is rejected/rebranded and not yet shipped,
   but the record exists; the platform can be added at or before tvOS submission.)
3. No Developer-portal App ID change needed (same bundle ID reuses the existing App ID).

## 4. 10-foot UI design direction (Item 2.4) — reconciled

Nav model, reconciling the smart-tv-developer vs apple-hig-expert split:

**Top tabs = Discover, Search, Requests, Watchlist (4 content tabs). Profile/Settings
= a top-bar ICON button, not a 5th tab.** (tech-architect call.)
- Grounded in a documented Apple tvOS tab-bar convention (settings/search as icon
  affordances, per Apple's Tab Bars page; TV/Photos apps do this). Keeps all 5
  features reachable at the top level and keeps the tab row reading as *content*.
- **Watchlist stays a top-level tab, NOT folded into Profile** (siding with HIG over
  smart-tv's fold). Watchlist is a homogeneous poster-grid browse surface — content,
  not chrome — and for a request client "see it on my watchlist → request it" is a
  primary couch action. Burying it two levels under a chrome tab inverts content-first
  10-foot design. smart-tv's own "promote it back if usage is high" hedge concedes
  the tab is the stronger default; ship it as a tab from day one.
- Net: this satisfies both consults' real intents — Profile is top-level (as the
  icon), Watchlist is a tab. Only the "hide Watchlist under Profile" idea is dropped.

**Requests = single-column list → full-screen push, NOT the iPad 2-column split
view.** (tech-architect call, siding with smart-tv over the HIG split-view option.)
- The HIG split-view sanction is for **filter-category → results** master/detail.
  Requests is **item-list → item-detail** (a long list of individual requests, each
  pushing to one request's detail) — a different information shape the split-view
  guidance doesn't actually endorse. The real "filter category" surface here is the
  status filter (pending/approved/available/declined), which becomes a focusable chip
  row above a single-column list.
- Single-column push gives one unambiguous focus zone per screen (no persistent
  left-list/right-pane D-pad traversal, no split-view Menu-behavior ambiguity), matching
  how tvOS's own Settings/TV apps do list→detail. It also avoids reusing the iOS-only
  size-class split branch in `RequestsTabView`.
- No admin on TV (create/track only; approve/decline stays phone/iPad) per existing
  project scope — so no D-pad-navigated approval forms.

Per-feature direction (tie to the actual 5 features):
- **Discover** = TV home. Larger "featured" trending rail lands first focus; standard
  poster rails below preserve the admin-configured slider order (same API data).
  Status badges: unfocused = a color+icon corner dot (green check / orange clock /
  purple down-arrow — never color alone); focused = expands to the full labelled pill.
  Reuse the real status colors (available=green, pending=orange, processing=purple,
  partiallyAvailable=orange).
- **Search** = design around no keyboard: open on a zero-typing state (recent-search
  chips + a Trending rail reusing Discover data); Siri Remote **dictation** is the
  primary text path, onscreen keyboard the fallback; movie/tv/person filter as
  focusable segmented chips; results as a poster grid (person = circular headshot).
- **Requests** = single-column (above).
- **Watchlist** = poster grid/rail; poster → Media Detail via concrete typed
  `NavigationLink` destinations (keep the app-wide no-`AnyHashable` rule).
- **Profile/Settings** = thin & read-only: account, server (no server-switching on TV),
  request summary, sign-out (with a confirmation screen — a couch mis-click sign-out is
  painful without a keyboard to re-login). Consider tvOS dark-only (drop the appearance
  toggle).
- **Media Detail (the conversion moment):** full-bleed 16:9 backdrop hero; the
  **Request button gets DEFAULT first-focus** the instant the screen appears (tvOS
  primary-action convention; the app's verb is Request, not Play) and stays the same
  control across state changes (label/state only). Overview as fixed lines + "More"
  push (no D-pad expand/collapse). Cast carousel and season/episode grid as focus rails.
  Season selection for TV requests = a focusable checkbox grid with Select-All/Clear at
  the TOP (not trailing).

**HIG hard numbers to build to:** safe area inset 60pt top/bottom, 80pt sides; poster
grid metrics ~860pt content width, 40pt horizontal spacing, 100pt min vertical spacing
(focus-scale headroom); typography floor 23pt / default 29pt, media title ~76pt; keep
badge/overlay content inset from poster edges (focus parallax crops flush edges); every
screen must tolerate the Menu button snapping focus to the top bar; Back walks the nav
stack one level (never redefine Back). **Layered app icon (2–5 layers) is a hard
submission requirement.** **Top Shelf** (best fit: a "Recently Requested" / "New in
Watchlist" Sectioned Content Row, static image 2320×720) is strongly recommended —
**verify current App Store Connect tvOS asset requirements before assuming it's optional.**

## 5. Sequencing note (flag)

`docs/planning/features.md` + project `CLAUDE.md` mark Smart TV as blocked until the
iPad + macOS layout phase completes and scope TV to "Discover, Search, Request, View
Requests — no admin." This pass is planning-only, which is consistent with producing it
now (Phase 1 iPad is closed per the current brief; STEPS authorizes tvOS at the
architecture-decision stage). **Actual target creation + implementation should confirm
that gate is satisfied before starting.**

---

## Current open items before tvOS can be called feature-complete

1. **User decision — Universal Purchase / same-record model.** Confirm same bundle ID
   `com.frostforgelabs.OctopusExplorer` under one ASC record (irreversible once two
   platforms approve). The target currently follows the same-bundle-ID plan, but final
   App Store Connect submission still needs owner confirmation.
2. **User/ASC manual action** — Add Platform → tvOS on the existing record (at/before
   submission). No App ID change needed.
3. **Design sign-off** on the two reconciled calls (4 tabs + settings icon; Requests
   single-column push) if the user wants to weigh in — documented with reasoning above,
   not silently chosen.
4. **Finish M3 app work** — real Search and interactive Plex tvOS login/OAuth.
5. **Add tvOS UI-test target** with `XCUIRemote` focus traversal and deterministic
   mock-auth scenarios.
6. **Final verification** — tvOS build/test + iOS regression build/test, simulator
   launch/screenshot/focus evidence, then push/PR only after the staged M3 scope is done.
