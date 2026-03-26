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

  /// Serializes this quote to a map suitable for sqflite insertion.
  ///
  /// The [author] key is always included even when the value is null — this
  /// is required by the sqflite nullable column contract so that anonymous
  /// quotes write a NULL rather than omitting the column entirely.
  Map<String, Object?> toMap() => {
        'id': id,
        'text': text,
        'author': author, // always include key; value may be null
      };

  /// Deserializes a sqflite row map into a [Quote].
  ///
  /// [row['author']] is cast as [String?] because anonymous quotes store NULL.
  factory Quote.fromMap(Map<String, Object?> row) => Quote(
        id: row['id'] as String,
        text: row['text'] as String,
        author:
            row['author'] as String?, // nullable — anonymous quotes are null
      );

  @override
  String toString() =>
      'Quote(id: $id, author: $author, text: ${text.substring(0, text.length.clamp(0, 40))}...)';
}
