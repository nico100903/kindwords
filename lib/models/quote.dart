/// Immutable value object representing a single motivational quote.
///
/// [id] is a stable string identifier used for favorites persistence.
/// [text] is the full quote body.
/// [author] is optional; null means the quote is anonymous.
class Quote {
  final String id;
  final String text;
  final String? author;

  const Quote({
    required this.id,
    required this.text,
    this.author,
  });

  /// Two quotes are equal if they share the same [id].
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Quote && other.id == id);

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'Quote(id: $id, author: $author, text: ${text.substring(0, text.length.clamp(0, 40))}...)';
}
