# Play reminders (local notifications)

Status: **built, Android; untested on a phone.** iOS files are installed (`ios/plugins/`) for the
later App Store build but not wired or tested. Nothing here sends data off the phone.

## Principles
1. **Local, not push.** The phone schedules its own reminders through the Notification Scheduler
   plugin (`addons/NotificationSchedulerPlugin`, v6.0, MIT, cengiz-pz / godot-mobile-plugins). No
   server, no Firebase, no network code, no Data safety change.
2. **Earned permission.** Android 13+ needs `POST_NOTIFICATIONS`. The game never asks on first
   launch: it asks in its own words first, and only a "Remind Me" shows Android's dialog.
3. **Useful, true, rare.** Each reminder points at something real. At most one a day, never in
   quiet hours, fewer when ignored. No ads, no fake urgency.
4. **Always reversible.** Settings → Play Reminders; Android's own channel settings also work.

## Workflow
```
 play ── 3 levels cleared or a Daily Challenge done ──► journey map / Daily screen opens
                                                          │ (1.2 s later, if not in a level)
                         soft question (ModalDialog): "Gentle Reminders"
                               [Remind Me]                  [Not Now]
                                    │                           │
                     Android permission dialog        asked once more after 7 days,
                     allowed │      │ refused          never more than twice
                             ▼      └──► off; no more questions; Settings switch
                       reminders ON                     (after repeated refusals it opens
                             │                           the phone's app page)
   app to background (NOTIFICATION_APPLICATION_PAUSED) → cancel all → ReminderPlanner → schedule
   app opens / resumes → count reminders already shown → cancel all → remember the play time
   reminder tapped → ignored = 0 → Daily calendar or journey map (never while a level is open)
```

## Rules (ReminderPlanner, unit-tested)
| Slot / id | When | Kind |
|---|---|---|
| 1 | today at the usual time, if today's Daily is not done | streak (≥ 3 days) or daily |
| 2 | tomorrow at the usual time | streak (if today's Daily is done and streak ≥ 3) or daily |
| 3 | day 3 | journey ("Level N is ready…") |
| 4 | day 7 | journey |

- Usual time = median start time of the last 10 sessions, kept within 10:00–20:30; default 19:00.
- Nothing within 4 hours of leaving the game; nothing from 21:00.
- One per calendar day (the slots are on different days).
- Shown but not tapped before the next open = ignored. 3 ignored → only the day-7 reminder;
  6 → none. A tap, or switching reminders on again, clears it.
- Texts in `data/reminders.json`, chosen by day number (no global RNG).
- Timing is inexact (Android may shift it a little). Reminders survive a reboot (plugin's boot
  receiver).

## Pieces
| Piece | File |
|---|---|
| Rules | `scripts/core/reminder_planner.gd`, tests `tests/unit/test_reminder_planner.gd` |
| Texts | `data/reminders.json` |
| Autoload | `scripts/autoload/reminders.gd` (state in `settings.cfg`, section `reminders`) |
| Phone side | `scripts/notifications/reminder_bridge.gd` (no-op), `android_reminder_bridge.gd` |
| Permission strip | `addons/zen_android_manifest` removes `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM` and `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` (Play restricts them for games) |
| Status-bar icon | `assets/NotificationSchedulerPlugin/android/drawable/ic_zen_notification.xml` (white lotus vector; the plugin copies it into the Android build) |
| Settings switch | `RemindersRow` in `scenes/components/audio_settings.tscn`, shown only where reminders work |
| Integration test | `tests/integration/reminders_test.tscn` (fake bridge, throwaway saves) |

Channel: "Gentle reminders" (default importance, no badge).

## Checking on a phone
- After leaving the game: `adb shell dumpsys alarm | grep -A3 com.zenmahjongjourney.game`.
- Permission flow: allow; refuse; refuse twice then Settings switch (opens app page).
- Tap a reminder with the app closed and in the background: opens Daily calendar / journey.
- Reboot: pending alarms come back. Switch off: nothing pending.
- Quick test: set the phone's clock forward past the planned time.
