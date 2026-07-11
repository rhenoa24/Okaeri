/// A quick emotional/status update a partner can send, distinct from the
/// Message Board (which is a full written note). Moodlets are lightweight —
/// tap once, partner gets notified instantly.
class Moodlet {
  final String id;
  final String label;
  final String emoji;

  /// How this moodlet reads in a push notification, e.g. "Aly is waiting for you!"
  /// {name} gets replaced with the sender's display name.
  final String template;

  const Moodlet({
    required this.id,
    required this.label,
    required this.emoji,
    required this.template,
  });

  String notificationBody(String senderName) =>
      template.replaceAll('{name}', senderName);

  static const List<Moodlet> premade = [
    Moodlet(
      id: 'waiting_for_you',
      label: 'Waiting for you',
      emoji: '⏳',
      template: '{name} is waiting for you!! ⏳',
    ),
    Moodlet(
      id: 'thinking_of_you',
      label: 'Thinking of you',
      emoji: '💭',
      template: '{name} is thinking of you, wherever you are. 💭',
    ),
    Moodlet(
      id: 'missing_your_voice',
      label: 'Missing your voice',
      emoji: '📞',
      template: '{name} misses your voice... 📞',
    ),
    Moodlet(
      id: 'feeling_low',
      label: 'Feeling low',
      emoji: '🌧️',
      template: '{name} is feeling low right now... 🌧️',
    ),
    Moodlet(
      id: 'okay',
      label: 'Okay',
      emoji: '🙂',
      template: '{name} is doing okay. 🙂',
    ),
    Moodlet(
      id: 'good',
      label: 'Good',
      emoji: '😊',
      template: '{name} is doing good! 😊',
    ),
    Moodlet(
      id: 'a_bit_jealous',
      label: 'A bit jealous',
      emoji: '😒',
      template: '{name} is feeling a bit jealous... 😒',
    ),
    Moodlet(
      id: 'need_a_hug',
      label: 'Need a hug',
      emoji: '🤗',
      template: '{name} needs a hug!! 🤗',
    ),
    Moodlet(
      id: 'want_kisses',
      label: 'Want kisses',
      emoji: '😚',
      template: '{name} wants kisses!! 😚😚😚',
    ),
    Moodlet(
      id: 'horny',
      label: 'Feeling horny',
      emoji: '😳',
      template: '{name} is feeling horny~ 😳',
    ),
    Moodlet(
      id: 'working',
      label: 'Working',
      emoji: '💼',
      template: '{name} is working right now. 💼',
    ),
    Moodlet(
      id: 'studying',
      label: 'Studying',
      emoji: '📚',
      template: '{name} is studying. 📚📚',
    ),
    Moodlet(
      id: 'taking_a_break',
      label: 'Taking a break',
      emoji: '🛋️',
      template: '{name} is taking a break~ 🛋️',
    ),
    Moodlet(
      id: 'in_a_meeting',
      label: 'In a meeting',
      emoji: '📋',
      template: '{name} is in a meeting! 📋',
    ),
    Moodlet(
      id: 'gaming',
      label: 'Gaming',
      emoji: '🎮',
      template: '{name} is gaming rn frfr 🎮',
    ),
    Moodlet(
      id: 'window_shopping',
      label: 'Window shopping',
      emoji: '🛍️',
      template: '{name} is window shopping. 🛍️',
    ),
    Moodlet(
      id: 'listening_to_music',
      label: 'Listening to music',
      emoji: '🎧',
      template: '{name} is listening to music. 🎧',
    ),
    Moodlet(
      id: 'tidying_up',
      label: 'Tidying up',
      emoji: '🧹',
      template: '{name} is tidying up! 🧹',
    ),
    Moodlet(
      id: 'overthinking',
      label: 'Overthinking',
      emoji: '🌀',
      template: '{name} is overthinking again... 🌀',
    ),
  ];
}
