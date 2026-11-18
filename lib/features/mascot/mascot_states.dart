/// Mascot animation states supported by the Unicorn Mascot component.
library;

enum MascotState {
  idle,
  welcome,
  walkIn,
  runIn,
  runAcross,
  thinking,
  curious,
  encouraging,
  correctAnswer,
  incorrectAnswer,
  timerWarning,
  timerUrgent,
  questionTimeout,
  celebration,
  rewardReveal,
  goodbye,

  // Character-sheet expressions (official emote set)
  /// Both arms up, jumping, eyes squeezed shut with joy.
  excited,

  /// Wink + point: "You got this!"
  youGotThis,

  /// Glasses on, reading a book, light-bulb idea.
  learning,

  /// Holding a trophy up with confetti.
  greatJob,

  /// Raised hoof wave: "Keep going!"
  keepGoing,

  /// Hooves clasped, heart: "Don't worry!"
  dontWorry,

  /// Running with speed dust: "Let's go!"
  letsGo,
}
