# Watch Score

An Apple Watch app for scoring tennis and padel matches, and keeping the stats
afterwards. Standalone watchOS app — no iPhone companion needed.

## What it does

- **Score a match with two taps per point.** One big button per side, a haptic on
  every point, a stronger one on every game, set and match.
- **Knows the rules.** 15/30/40, deuce and advantage, golden point (*punto de
  oro*) for padel, tiebreak at 6-6 with the right serving rotation, 1 set or best
  of 3.
- **Tells you what is at stake.** The score screen calls out game point, set
  point, match point and golden point as they come up.
- **Undo any point**, however far back — useful when you tap for the wrong side.
- **Stats when the match ends:** points won, points share, points won on serve,
  games, breaks of serve and longest run of points, for both sides.
- **History** of every match, with your win/loss record per sport.

Matches are stored on the watch as a JSON file, so there is nothing to set up
and nothing leaves the device.

## Running it

1. Open `WatchScore.xcodeproj` in Xcode 15 or newer.
2. Select the **WatchScore** scheme and an Apple Watch simulator, then Run.
3. To run it on your own watch, pick your team under *Signing & Capabilities*
   and change the bundle identifier from `com.example.WatchScore` to something
   of your own.

Requires watchOS 10 or newer.

## How it is put together

| File | What lives there |
| --- | --- |
| `Models/MatchEngine.swift` | All the scoring rules, as one value type. `score(_:)` is the only way a match moves forward. |
| `Models/MatchStats.swift` | Counters kept as the match is played, so the summary needs no replay. |
| `Models/MatchController.swift` | Undo stack and haptics for the match on screen. |
| `Models/MatchRecord.swift` | A finished match, as it is stored. |
| `Storage/MatchStore.swift` | The match history file, and the last format used. |
| `Views/` | The five screens: home, new match, scoring, summary, history. |

The engine is a plain `struct` with no UI or storage in it, which is what makes
undo a matter of keeping the previous value around.

## Ideas for later

- Keep the app awake during a match with a `HKWorkoutSession`, so it survives a
  dropped wrist, and record calories and heart rate alongside the score.
- Serve/return splits per set, and stats across matches (win rate by opponent,
  by sport, by month).
- A complication to start a match straight from the watch face.
- Doubles: name the four players and track who served.
