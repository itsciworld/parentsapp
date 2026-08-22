/// How many days of history the Social Apps (chats) screen asks the API for.
///
/// `/api/social/screen` applies a 2-day window server-side when `days` is left
/// off, which silently hides anything captured before that: a child device that
/// was offline for a few days, or a capture backfilled from an older session,
/// comes back as an empty screen with no error to explain it. 60 days covers
/// every capture we expect to show while keeping the payload bounded.
///
/// The screen sends this fixed value for now — the history dropdown that used
/// to vary it is commented out in the view.
const int kSocialHistoryDays = 60;
