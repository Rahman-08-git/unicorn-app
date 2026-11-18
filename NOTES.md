# Project Notes

## About the codebase

**Unicorn Learning Lab – Education 4.0** is a Flutter kiosk app for campaign events. It runs on tablets (Android, landscape preferred, fullscreen), and the web build is used for previews. A visitor picks who they are (parent, guardian or student), answers 5 timed quiz questions for their group, sees their score, and wins a physical reward (premium gift, a score 3–4 gift, or sticker), always revealed with a spin wheel. Then the app resets itself for the next visitor. Everything works offline: data lives in a local SQLite database on the tablet, and operators export it as CSV.

**How it fits together**
- `main.dart` creates the services with `provider` and shows `AppRouter`.
- **One state machine drives navigation.** `SessionService` holds the current `SessionStage`, and `AppRouter` swaps screens when it changes, so there's no named-route navigation. A screen moves the flow on by calling a `SessionService` method such as `goToRewardReveal()`.
- **Services hold the logic; screens are UI.** Scoring, rewards, timer, question banks and export are plain Dart classes in `lib/services/`.
- **Persistence** goes through the single `DatabaseHelper`, which talks to SQLite. Its tables are `participants`, `attempts`, `answers`, `rewards`, `reward_inventory`, `campaign_config`, `custom_questions` and `app_settings`.
- **Privacy:** students give no phone number; their name is optional. Parents and guardians give a phone number and a name (both required).
- **Design and motion:** `app/theme.dart` (colours, typography) and `core/ui/ull_ui.dart` (shared buttons, backgrounds, motion tokens, and a reduced-motion setting) are used by every screen.

## Project structure

```
lib/
  main.dart                 App entry: orientation + immersive mode, opens the DB, registers services (provider), MaterialApp
  app/
    router.dart             AppRouter: maps SessionStage → screen, animated screen transitions
    theme.dart              AppColors (brand palette), AppTheme (Manrope typography, component themes)
  core/
    constants/app_constants.dart  App name, campaign IDs, DB name/version, questions per attempt (5), timer (60 s),
                                  auto-reset (45 s), score titles, reward type codes
    ui/ull_ui.dart          Shared design + motion kit: Motion tokens, reduced-motion pref, buttons, backgrounds, BrandMark
  data/
    database/database_helper.dart  SQLite schema, migrations, seed data, CRUD for every table
    models/                 participant (+ AudienceCategory), attempt, answer, question (+ options), reward,
                            reward_inventory, campaign_config (timer, reward mode, operator PIN, …)
    question_banks/default_questions.dart  Built-in question bank for every audience (Class 1–12, College,
                            Parent, Guardian, Demo)
  services/
    session_service.dart    The flow state machine: registration, starting a quiz, answers, timeouts, finishing the
                            attempt, reward allocation, inactivity auto-reset
    question_bank_service.dart  Loads built-in + operator-edited questions, picks/shuffles 5 per attempt, validation,
                            JSON import/export
    quiz_timer_service.dart Deadline-based countdown (doesn't drift when frames drop or the app pauses)
    scoring_service.dart    Score (0–5) → result title, message and reward type
    reward_service.dart     Checks inventory, assigns a physical reward or a fallback, saves it
    export_service.dart     UTF-8 CSV reports (per-visitor Quiz Report, Gift Inventory, Summary)
    storage_bridge.dart     MethodChannel to Android's folder picker (native side:
                            android/app/src/main/kotlin/com/unicornlearninglab/campaign/MainActivity.kt)
  features/                 One folder per screen (see "App screens")
    welcome/ audience_selection/ registration/ student_class_selection/ quiz/ results/
    rewards/ education_intro/ thank_you/
    operator_dashboard/     Operator dashboard, PIN dialog, question bank editor
    interactive_challenge/  Robot path-sequencing puzzle (optional mini-game)
    mascot/                 "Uni" the unicorn: mascot_states.dart (MascotState enum), unicorn_mascot.dart (widget:
                            roaming, gallop in/out, tap, speech bubble), unicorn_rig.dart (pose logic + vector drawing)
assets/questions/           Question banks as JSON (one file per audience + all_questions_v1.0.json)
tool/generate_questions_json.dart  Regenerates assets/questions/*.json from default_questions.dart
test/
  unit/                     Export, participant privacy, question bank, quiz timer, scoring & rewards
  widget/                   Full-journey tests (app_journey, extended_journey, quiz_journey) + mascot_motion_test
design/                     Mascot reference images and pose sheets
web/                        Web build shell (index.html, manifest)
android/                    Android project (kiosk app, native folder picker)
flutter/                    Local Flutter SDK used by flutter_run.ps1 / flutter_run.bat
```

## App screens (in flow order)

| Stage (`SessionStage`) | Screen | What happens | Uni's state |
|---|---|---|---|
| `welcome` | `WelcomeScreen` | Start button and a **Demo** quiz. Long-press the brand mark to open the operator PIN dialog. Also opens the Robot Puzzle challenge. | `welcome` |
| `audienceSelection` | `AudienceSelectionScreen` | Pick Parent, Guardian or Student. | `curious`, `celebration` |
| `parentRegistration` / `guardianRegistration` | `RegistrationScreen` | Phone number, optional name, consent. | `curious`, `encouraging`, `celebration` |
| `studentClassSelection` | `StudentClassSelectionScreen` | Big tiles for Class 1–12 and College (no personal data). | `curious`, `celebration` |
| `quiz` | `QuizScreen` | 5 questions, one at a time. 60 s deadline timer, a single locked answer, inline feedback. | `thinking`, `correctAnswer`, `incorrectAnswer`, `timerWarning`, `timerUrgent`, `questionTimeout` |
| `results` | `ResultsScreen` | Score counts up, then the title, a breakdown and whether a reward was won. | `celebration`, `encouraging` |
| `rewardReveal` | `RewardRevealScreen` | Treasure chest, then the spin wheel for every tier. The reward is already assigned and saved before the reveal. | `rewardReveal`, `thinking`, `curious` |
| `educationIntro` | `EducationIntroScreen` | Education 4.0 explainer: Think · Explore · Discover. | `learning` |
| `thankYou` | `ThankYouScreen` | Goodbye, then a countdown that resets automatically to Welcome (inactivity timer). | `goodbye` |

**Outside the main flow**
- `OperatorPinDialog` → `OperatorDashboardScreen`: protected by a PIN (default `1234`, stored in campaign config). It has five tabs:
  - **Overview**: analytics
  - **Participants**
  - **Inventory**: reward stock
  - **Question Bank**: opens `QuestionBankEditor` to add, edit, delete or restore questions for each audience
  - **Settings & Export**: timer, reset delay, CSV export (readable Quiz Report) to a folder you pick
- `RobotPuzzleDialog`: an offline mini-game about sequencing and algorithmic thinking.

**Reward tiers** (`ScoringService`): 5/5 → premium gift · 3–4 → spin wheel gift · 0–2 → sticker (all revealed with the spin wheel).

**Run commands:** see "Run commands" in the mascot redesign entry below (`flutter_run.ps1 analyze | test | build web`; the `web-preview` launch config serves `build/web`).

## 2026-11-18 (later): Required parent name, student name screen, Pre-Primary class

### What changed
- **Parent/Guardian registration:** the name is now required (at least 2 characters after trimming) along with the phone number. The "educational insights" consent checkbox is gone. The `consent_given` column stays in the DB (no migration), but the dashboard's participant details and the CSV Quiz Report no longer show a Consent column.
- **Student name screen** (`features/student_name/student_name_screen.dart`, new stage `SessionStage.studentNameEntry`): Student → name → class. The name is optional ("Skip" link). `SessionService.submitStudentName` keeps it as `pendingStudentName` until `registerStudent` saves it on the participant. Back from class selection returns to the name screen with the name kept; a reset clears it. The class screen's mascot greets the student by first name. This changes the old "students give no name" rule.
- **Pre-Primary class** (`PRE_PRIMARY`, shown as "Pre-Primary", "Early Years" band, orange): first tile in `AppConstants.studentClassLevels`. It has 5 built-in questions in `default_questions.dart` (and `assets/questions/questions_pre_primary.json`, regenerated). It shows in the dashboard's Question Bank tab (editable like any class), in the participant labels, in the quiz header and in the CSV.
- **Dashboard Overview** has a new "Students by Class" card (Pre-Primary, Class 1–12, College) built from `classBreakdown`. The CSV Summary adds a "Students - <class>" row for each class.

### Tests
All 40 pass. The updated tests cover the required name and the missing checkbox, the name → class flow with the Pre-Primary tile, PRE_PRIMARY in the bank check, and the CSV (a Pre-Primary student with a name, no Consent column, the per-class summary row). The web preview was checked by hand: the parent form, the student name screen, the class grid and a Pre-Primary quiz.

### Open items
- The dashboard's new Overview card and the Pre-Primary entry in the Question Bank tab were not checked by eye. The web build has no SQLite, so the stats there are empty.

## 2026-11-18: Operator dashboard fixes (gift names, question edits, CSV, spin wheel only)

### What changed
- **Renamed gifts show everywhere.** The results and reward screens used fixed names per tier. `SessionService` now looks up the gift's current `display_name` when the reward is assigned (`assignedRewardName`). `ResultsScreen` ("You unlocked …"), the reward card and the claim box all use it.
- **Question bank → quiz.** The wiring was already right: the editor and the quiz share the one `QuestionBankService` from `provider`, and `saveQuestion` updates memory and SQLite. No code change was needed. `test/widget/operator_changes_test.dart` now proves it end to end: edit the text and options in the editor, then the quiz shows them and scores the new correct answer. Note: options are shuffled in the quiz, so "Option B" in the editor can show up as C on the quiz screen. That's intended.
- **Readable CSV export** (`ExportService.buildCsvFiles`). Three files replace the five raw table dumps, which were full of UUIDs, ISO timestamps and codes like `CLASS_5`:
  - `Quiz_Report_<tablet>_<stamp>.csv`: one row per visitor attempt, plus visitors who registered but never started. Columns: date, start/end time, time taken, visitor type, name, phone, class, consent, status, score, result title, correct/wrong/timed-out counts. Then, for Q1–Q5: question text, the visitor's answer text, the correct answer text, the result and the seconds taken. Then reward tier, gift name, gift status and collected-at.
  - `Gift_Inventory_…csv` and `Summary_…csv`.
  - Question text comes from `QuestionBankService`, which the dashboard now passes to `ExportService`. The fallback file writer now adds a UTF-8 BOM, as the Android writer already did. Adds `DatabaseHelper.getAllAnswers()`.
- **Scratch card removed; the spin wheel is used for every tier.** After the chest, every reward (premium, 3–4, sticker) goes to the spin wheel, which lands on the assigned gift. The `Reward mode` picker is gone from Settings. `ScoringService.getRewardTypeForScore` no longer takes `rewardMode`: 3–4 always maps to `SPIN_WHEEL`. If premium stock runs out, the fallback is now the 3–4 tier.
  - **DB v3 migration:** gifts in the `SCRATCH_CARD` tier keep their name and stock but move to `SPIN_WHEEL` (3–4), and `reward_mode` becomes `spin_wheel`. New installs seed "Stationery Set" in the 3–4 tier.
  - Old reward records may still say `SCRATCH_CARD`; they are shown as the 3–4 tier.
  - The 3–4 tier prefers `SPIN_WHEEL_GIFT` while it's in stock, then the other gifts in the order they were added.
- **Layout fix:** the reward card overflowed when a long gift name wrapped to two lines. It now scales down to fit.

### Tests
`test/widget/operator_changes_test.dart` covers:
- a renamed gift at scores 5, 4, 3 and 1, shown on the results screen and after chest → spin → card
- a question bank edit reaching the quiz
- the CSV content: readable, with no UUIDs or codes

The full suite (40 tests) passes. The web preview was checked by hand: demo quiz → results → chest → spin wheel → card. The web build has no SQLite, so it shows the default gift names there.

### Open items
- Not yet run on an Android tablet: the v3 migration on an existing database, and opening a real export in Excel.

## 2026-11-15 (later): Uni back on four legs + neutral face

### Goal
Uni walks on four legs again (not upright), keeps every expression/state from the upright redesign below, and has a gender-neutral face.

### What changed (`lib/features/mascot/unicorn_rig.dart` only)
- **Quadruped rig.** Side-on barrel body facing right, four legs (`fn`/`ff` = front near/far, `bn`/`bf` = hind near/far), each with hip + knee. The arms are gone; `UnicornPose` now has `fnHip, fnKnee, ffHip, ...` and a `rear` angle (< 0 tips the body back onto the hind hooves).
- **Gestures move to the near front hoof.** `HandShape` was replaced by `HoofGesture { plain, sole, bump, point }`:
  - wave / Keep Going → hoof raised, underside (`sole`) showing
  - thumbs-up → raised "hoof-bump" with a gold sparkle
  - You Got This → hoof stretched straight forward (`point`)
  - Great Job → trophy balanced on the raised hoof (drawn upright on screen)
  - Don't Worry → hoof folded to the chest
  - Thinking → tapping a front hoof; Curious → "pointer" pose (one hoof lifted)
  - Excited → hop + rear up with both front hooves prancing
  - Learning → open book lying on the ground in front, head lowered, glasses on
- **Locomotion.** `_walk` is a four-beat walk (hind near → front near → hind far → front far); `_run` is a gallop (front pair vs hind pair, far leg trailing). Walk amplitude 0.5 at 1.7 Hz still matches the roaming speed in `unicorn_mascot.dart`.
- **Neutral face.** No cheek blush, no heavy upper lid; medium-sized calm eyes with one catch-light; thinner level brows (no inward "confident" tilt); inner ears and muzzle are cool grey-lavender instead of pink/peach; grey-navy nostrils.
- **Layout.** Head is drawn in its old 200-box coordinates, then shifted by `_headShift` (30, 12) and rotated around `_neckPivot`; a neck shape joins it to the body. Emotes are offset by (26, 6) to stay around the head. Sash is a band around the barrel with the badge on the side.
- **Draw order:** far legs → tail → body/sash/badge → near hind leg → back mane, neck, head → book → near front leg (so a raised hoof and the trophy sit in front) → emotes.
- **Unchanged:** `MascotState`, `UnicornMascot` widget API, roaming, gallop in/out, tap reaction. `mascot_motion_test.dart` passes.
- Pose sheet of the new look: `design/mascot_quadruped_poses.png`.

### Open items
- Only checked as rendered still images and via the widget tests; not yet looked at in the running app.

## 2026-11-15: Mascot redesign (Uni the unicorn)

### Goal
Make Uni look like the official character sheet (an upright chibi unicorn with a thumbs-up, a spiky red/blue/purple mane, navy hooves, the sash and badge, and a blue spiral horn) and make it look less feminine. Uni should also be able to show the 9 expressions from the sheet: Excited, Thinking, You Got This!, Learning, Great Job!, Keep Going!, Don't Worry!, Let's Go!, Goodbye.

### Decisions
- **Redraw, don't add images.** Uni is still a vector rig drawn in code with Flutter `CustomPainter`, so every pose stays animated and reacts as before. Uni is still a flat cartoon, not the 3D plush look; matching that would need image files.
- **Upright, not four-legged.** (Superseded: Uni is four-legged again, see the entry above.) The old rig was a side-on quadruped. The new one stands on two legs in a 3/4 view facing right and has arms (shoulder, elbow, hand). Turning left still works by mirroring the whole drawing.
- **What makes it less feminine:**
  - no eyelashes; a thick upper eyelid line instead
  - bold navy eyebrows tilted slightly inward, so he looks confident
  - fainter, smaller pink cheeks
  - a spikier, bigger mane
  - navy hooves and hands instead of lavender
  - a sturdier pear-shaped body
- **Same public API.** `UnicornMascot` and the existing `MascotState` values didn't change, so no screen broke. Existing states now map to the new expressions:
  - `celebration` → Excited
  - `correctAnswer` → Great Job
  - `encouraging` → You Got This
  - `incorrectAnswer` → a short sad moment, then Don't Worry (supportive, never humiliating)
  - `runIn` / `runAcross` → Let's Go
  - `goodbye` → wave with closed happy eyes
- **New states added** so screens can ask for a sheet expression directly: `excited`, `youGotThis`, `learning`, `greatJob`, `keepGoing`, `dontWorry`, `letsGo`.
- **Raised arms go out to the sides** ("yay!" arms) instead of straight up. The chibi arms are too short to reach above the big head, and going up made the hooves cover the face.
- `learning` doesn't roam: Uni stays still while reading.

### Files changed
- `lib/features/mascot/unicorn_rig.dart`: full rewrite of the pose logic and the drawing. Adds arms and hand shapes (mitt, open, fist, thumbs-up, point), props (book, glasses, trophy), and new emotes (burst lines, confetti, light bulb, single heart, purple "?").
- `lib/features/mascot/mascot_states.dart`: adds the 7 sheet-expression states.
- `lib/features/education_intro/education_intro_screen.dart`: the mascot now uses `MascotState.learning`.
- Unchanged: `unicorn_mascot.dart` (widget, roaming, gallop in and out, tap) and `test/widget/mascot_motion_test.dart` (still passes).

### Learning steps (how this works / how to repeat it)
1. **Find the mascot.** It's a single painter rig. `computeUnicornPose(state, t, s)` returns a `UnicornPose`: `t` is global time and `s` is seconds since the state started. `UnicornArt.paint` draws that pose. `UnicornMascot` runs one ticker and repaints every frame without rebuilding widgets.
2. **Coordinate space.** Everything is drawn in a 200×200 design box, with the feet on the ground at y≈192 and the horn tip at y≈-6. `paint()` scales by 0.85 and shifts down to leave room for raised arms and emotes.
3. **Arm angles are "raise" angles.** 0 = hanging down, π/2 = straight out sideways, π = straight up, negative = across the chest. `armXUp` is the upper arm and `armXLow` is the forearm's absolute angle (not relative to the upper arm). The left arm is the right arm mirrored, and the hand is always drawn upright on screen, so a thumbs-up always points up.
4. **Leg angles.** A positive hip angle swings the foot forward (the way Uni faces). A positive knee angle bends the shin backward.
5. **Adding an expression:**
   - add a value to `MascotState`
   - add a `case` in `computeUnicornPose`
   - write a small helper (like `_greatJob`) that sets arms, hands, eyes, mouth, props and an `Emote`
6. **Fast visual iteration.** Write a temporary `flutter test` that uses a `PictureRecorder` to paint a grid of poses. Have it call `computeUnicornPose` and `UnicornArt.paint`, then save the result to a PNG. Look at the PNG, tweak the numbers, and re-run. This is much faster than rebuilding the app. Note: test fonts draw text as boxes, so the "?" and "!" emotes show as squares there; they render fine in the app.
7. **Run commands** (use `flutter_run.ps1`; it sets the local Flutter SDK and cache paths):
   - `.\flutter_run.ps1 analyze lib/features/mascot`
   - `.\flutter_run.ps1 test test/widget/mascot_motion_test.dart`
   - `.\flutter_run.ps1 build web`, then start `web-preview` (in `.claude/launch.json`), which serves `build/web` on port 8765.
8. **Using an expression on a screen:** `UnicornMascot(state: MascotState.keepGoing, message: 'Keep going!')`.

### Open items
- `keepGoing` isn't used on any screen yet.
- Only the welcome screen was checked in the browser. The other expressions were checked as rendered still images.
