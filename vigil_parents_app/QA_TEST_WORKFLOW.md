# Vigil Parents App — QA Test Workflow

**Build:** v1.0.0 (+1) · **Branch:** `dev_new` · **Platforms:** Android + iOS
**Doc date:** 19 Jul 2026 · **Owner:** _(dev)_ · **Tester:** _(assign)_

---

## 1. What this app does

Vigil Parents is the **parent-side** companion app. A parent signs up, links one or
more **child devices**, and then monitors that child's activity: location, calls,
SMS, contacts, gallery, app usage, social-app notifications, and an AI-generated
daily insight report.

There are **two apps** — the parent app (this repo) and the child app. Most data on
the parent side only appears **after a child device is linked and has synced**. This
is the single most important thing for the tester to understand.

---

## 2. Before you start (setup)

| # | Step | Notes |
|---|------|-------|
| 1 | Install the build on a test device | Android 10+ / iOS 15+ recommended |
| 2 | Get the **child app** build installed on a second device | Required for any data to show |
| 3 | Confirm the backend environment | Base URL comes from `.env` (`BASE_URL`) — dev/staging should be confirmed by dev before testing |
| 4 | Get 2 test parent accounts + 1 real email inbox | OTP is emailed, so the email must be reachable |
| 5 | Grant child-device permissions | Location, contacts, SMS, call log, notification access, storage — on the **child** device |

> ⚠️ If the child device has not granted a permission, the matching parent-side
> screen will be empty. That is expected behaviour, **not a bug** — but please
> note which permission was missing in the report.

---

## 3. Test flow (run in this order)

The screens are dependent on each other, so please test top-to-bottom.

### Phase 1 — Onboarding & Auth
1. **Intro / onboarding screens** — swipe through, skip button, get-started button.
2. **Signup** — valid data, invalid email, weak password, duplicate email.
3. **OTP verification** — correct OTP, wrong OTP, expired OTP, resend OTP.
4. **Login** — correct credentials, wrong password, unregistered email.
5. **Forgot password → OTP → Reset password** — full chain.
6. **Splash / auto-login** — kill the app and reopen; the user must land on Home,
   not Login. (Token refresh happens silently here.)
7. **Logout** — must clear the session; reopening should land on Login.

### Phase 2 — Child linking
8. **No child linked state** — fresh account should show the "no child linked"
   empty screen with a clear call-to-action.
9. **Link a child device** — follow the in-app pairing flow with the child app.
10. **Multiple children** — link a 2nd child; the **child selector dropdown** in the
    header must switch all data on every screen.
11. **Edit child name** — rename, save, confirm it updates everywhere.
12. **Delete child** — confirm dialog appears; cancel does nothing; delete removes
    the child and its data from all screens.

### Phase 3 — Home dashboard
13. **Live status card** — Status (online/offline), Battery %, Charging state,
    Last sync time. Compare against the real child device.
14. **Location card** — current location shown on Home; tap → Location detail.
15. **Feature badges / quick tiles** — every tile must open the correct screen.
16. **Pull-to-refresh** on Home.

### Phase 4 — Monitoring screens
Test each of these for: data loads, empty state, error state, pull-to-refresh,
pagination/scroll, and back navigation.

| Screen | Key checks |
|---|---|
| **Location history** | Timeline of locations, map markers, tap a point for detail |
| **Calls** | Incoming / outgoing / missed, duration, contact name, timestamps |
| **SMS** | Sender, message body, timestamp, long messages don't overflow |
| **Contacts** | Full list, search, correct count |
| **Gallery** | Photo grid, full-screen viewer, video playback, swipe between media |
| **App usage** | Per-app time, activity overview chart, app icons render |
| **Social apps** | Installed social apps detected correctly |
| **Notifications** | Social-app notifications with app name + timestamp |
| **Events** | Event list renders and sorts correctly |
| **Device info** | Model, OS version, storage — matches the real child device |

### Phase 5 — AI Insights
17. Open the **AI Insights** tab — a fresh analysis runs **every time** you land on
    the tab. First visit shows a shimmer loader; revisits refresh silently.
18. Switch child → the report must regenerate for the new child.
19. Open the **full AI report** view; check readability and that no text is cut off.
20. Test with a child that has **no data** — should show a graceful empty/soft state,
    not a crash or an infinite loader.

### Phase 6 — Profile & Settings
21. **Profile** — view and edit parent details, save, reload to confirm persistence.
22. **Settings** — every toggle/option opens and persists.
23. **Change password** (if present in build).

### Phase 7 — Navigation & app behaviour
24. **Bottom nav** — Home / Child / AI Insights / Profile all switch correctly.
25. **Android back button:**
    - On a non-Home tab → returns to the Home tab.
    - On Home tab → first press shows a snackbar, second press within 2s exits.
26. **Backgrounding** — background the app for 5+ min, return; data should refresh
    and the session should still be valid.
27. **Notification permission prompt** on Android 13+.

### Phase 8 — Negative & edge cases
28. **Airplane mode / no internet** — every screen must show a proper error state
    with a "Try Again" button, never a blank screen or an endless spinner.
29. **Slow network** (throttle to 3G) — loaders behave, no duplicate requests.
30. **Session expiry** — leave the app idle for a long period; the token should
    refresh silently. If refresh fails, the user must be sent to Login cleanly.
31. **Child device offline** — parent app should show last-known data + a stale
    "last sync" time, not an error.
32. **Rotation / large font / dark mode** — layout must not break.

---

## 4. Bug reporting format

Please log every issue with **all** of these fields:

```
Title:        [Screen] Short description
Severity:     Blocker / Critical / Major / Minor / Cosmetic
Device:       e.g. Samsung S21, Android 14
Build:        v1.0.0 (+1) — dev_new
Steps to reproduce:
  1.
  2.
  3.
Expected result:
Actual result:
Frequency:    Always / Intermittent (x out of y)
Attachment:   Screenshot or screen recording (mandatory for UI issues)
Child device state: (permissions granted? online? last sync time?)
```

### Severity guide
- **Blocker** — cannot proceed: crash on launch, login broken, cannot link a child.
- **Critical** — a core feature is unusable: location/calls/SMS never load.
- **Major** — feature works but is wrong: incorrect data, wrong timestamps.
- **Minor** — small functional issue with a workaround.
- **Cosmetic** — spacing, alignment, copy, colour.

---

## 5. Sign-off checklist

The build is ready to move forward only when:

- [ ] Full auth chain (signup → OTP → login → forgot password → logout) passes
- [ ] Child linking, switching, renaming and deleting all pass
- [ ] All Phase 4 monitoring screens load real data from a live child device
- [ ] AI Insights generates a report for a child with data and handles no-data
- [ ] No crashes recorded across the full pass
- [ ] Offline / error states verified on every screen
- [ ] Tested on at least 2 Android devices and 1 iOS device
- [ ] All Blocker and Critical bugs are closed and retested

---

## 6. Out of scope for this round

- Child-app internals (tested separately)
- Backend/API load and performance testing
- Push-notification delivery infrastructure
- Payments / subscriptions (not in this build)

---

## 7. Contacts

| Role | Name | Contact |
|---|---|---|
| Developer | _(fill in)_ | |
| QA Lead | _(fill in)_ | |
| Backend | _(fill in)_ | |

**Questions during testing → ping the developer directly rather than blocking.**
