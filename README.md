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
4. Finish, and see how you did: time, guess, difference, coins, streak, and
   a distinct celebration if it's a new record.

## Features

- **Ghost racing** — the timer screen shows your live progress against your
  fastest-ever run for that task.
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
  reads as "idle," not "missing."
- **Run history** — every past run for a task, with date, guess, actual
  time, and win/loss, for debugging the numbers above it.
- **Coins & streak** — beating your estimate builds a streak and pays coins;
  running over breaks the streak and costs coins. A skip-penalty token
  (bought with coins) protects your streak once.
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
  restores the running session from the correct elapsed time, not zero.
- **Persistence** — tasks and run history are saved locally
  (`shared_preferences`) and reload on next launch.

## Project structure

```
lib/
  main.dart                    entry point
  app.dart                     app shell, AppScope (DI), startup gating
  core/
    theme.dart                 app theme
    formatters.dart            time/date formatting
    accuracy.dart              estimate-accuracy math
  models/
    task.dart                  Task, TaskRun
  data/
    task_repository.dart       persisted task/run storage
    active_session_store.dart  in-flight timer session, survives a kill
  state/
    session_controller.dart    live timer state for one run
    stakes_controller.dart     coins, streak, skip-penalty tokens
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
