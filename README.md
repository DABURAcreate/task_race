# Ghost Timer

A Flutter task timer built around one idea: guess how long a task will take,
then race a "ghost" of your own best time while you do it. It's for daily
tasks — studying, research, work, drawing — not chores.

## The core loop

1. Pick a task and guess how long it'll take.
2. Start the timer. A ghost bar fills alongside yours, paced by your personal
   best for that task.
3. Cross your estimate and you'll know it — a haptic buzz, a red screen
   flash, and a notification (even if you've switched apps).
4. Finish, and see how you did: time, guess, difference, streak, and a
   distinct celebration if it's a new record.

## Features

- **Ghost racing** — the timer screen shows your live progress against your
  fastest-ever run for that task.
- **Pause & resume** — a real interruption (a call, someone walking in)
  shouldn't inflate your time or poison the ghost it feeds. Pause freezes
  the clock and the ghost bar together; resume picks the same run back up.
  Paused time is banked out of the run entirely, not counted then
  subtracted, so the final time is exactly what you spent actually doing
  the task.
- **Cancel a run** — the close icon (or the back gesture/button, which asks
  the same thing) discards the run after a confirmation: no run saved, no
  effect on your streak. For the wrong task started by mistake, or one
  abandoned outright — "Done" always records a run, so it's the wrong exit
  for either case.
- **Categories** — tasks are tagged with a free-text category (autocomplete
  suggests ones you've already used). A new task under an existing category
  inherits that category's accuracy history immediately.
- **Grouped task list** — the home screen buckets tasks into one collapsible
  section per category (task count and category accuracy up front), so the
  list stays short as tasks pile up instead of growing one row per task.
- **Weekly insights** — a dedicated screen surfaces estimate accuracy by
  category over the last 7 days ("You underestimate Cleaning by 60%"),
  pooling runs from every task in that category, deleted or not. Categories
  with no sessions this week are listed separately, so a quiet category
  reads as "idle," not "missing." Swipe a card left to dismiss it (with an
  Undo snackbar) — this only hides the card, it doesn't touch task or run
  data, and the card comes back on its own the next time that category logs
  a run.
- **Run history** — every past run for a task, with date, guess, actual
  time, and win/loss, for debugging the numbers above it.
- **Streak** — beating your estimate builds a streak; running over resets it
  to zero.
- **Edit & soft delete** — long-press a task for a rename/delete menu (rename
  covers both its name and category), or swipe it away to delete directly.
  Deleted tasks disappear from your list but their runs stay in the category
  insights above, so tidying up doesn't skew your stats.
- **Category rename** — the edit icon on a category's section header renames
  it across every task in that category at once (including deleted ones),
  so the category keeps one accuracy history instead of splitting in two.
  Renaming to an existing category's name merges the two.
- **Category delete** — swipe a category's section header left to soft
  delete it and every task inside it in one action (with a confirmation
  showing how many tasks are affected). Swiping an individual task row
  still deletes just that task; their runs stay in category insights
  either way.
- **Session survival** — if the app is killed mid-timer, relaunching it
  restores the session from the correct elapsed time, not zero — and if it
  was paused when the app died, it comes back paused, not silently ticking.
- **Persistence** — tasks and run history are saved locally
  (`shared_preferences`) and reload on next launch.

## Theme

A fixed dark blue palette, defined once as `AppColors` in `lib/core/theme.dart`
and wired into `ThemeData` (backgrounds, cards, buttons) plus referenced
directly by the ghost bar:

| Color | Hex | Used for |
| --- | --- | --- |
| Background | `#03045E` | Scaffold background |
| Surface | `#012A4A` | Cards, progress bar tracks |
| Primary | `#00B4D8` | Your progress bar, filled buttons, FAB |
| Ghost | `#2C7DA0` | The ghost's progress bar |
| Label | `#90E0EF` | Labels and secondary text (list subtitles, captions) |

Status colors (win/loss, delete, new-record) stay separate from this palette
since they're semantic, not decorative.

## Project structure

```
lib/
  main.dart                    entry point
  app.dart                     app shell, AppScope (DI), startup gating
  core/
    theme.dart                 app theme, AppColors palette
    formatters.dart            time/date formatting
    accuracy.dart              estimate-accuracy math
  models/
    task.dart                  Task, TaskRun
  data/
    task_repository.dart       persisted task/run storage
    active_session_store.dart  in-flight timer session (paused or running), survives a kill
    insights_dismissal_store.dart  which weekly-insight cards are hidden
  state/
    session_controller.dart    live timer state for one run, incl. pause/resume
    streak_controller.dart     win/loss streak
  services/
    notification_service.dart local notification wrapper
  screens/
    home_screen.dart           task list, add/edit/delete
    timer_screen.dart          the race itself
    summary_screen.dart        post-run result
    history_screen.dart        per-task run log
    insights_screen.dart       weekly per-category accuracy
  widgets/
    ghost_bar.dart             the two-bar race visual
```

## Running it

```
flutter pub get
flutter run
```

Notification permission (Android 13+) is requested the first time you start
a timer, not on launch — so the prompt has an obvious reason behind it.
