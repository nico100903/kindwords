import 'dart:convert';

/// The origin of a quote: either seeded from the bundled catalog or created
/// by the user within the app.
enum QuoteSource {
  seeded,
  userCreated,
}

/// Immutable value object representing a single motivational quote.
///
/// [id] is a stable string identifier used for favorites persistence.
/// [text] is the full quote body.
/// [author] is optional; null means the quote is anonymous.
///
/// v2 fields:
/// [tags] is a list of predefined category labels (0–3 values).
/// [source] identifies whether the quote is seeded or user-created.
/// [createdAt] is the timestamp when the quote was stored; null for v1-style
///   constructor usage (backward-compatible with const construction).
/// [updatedAt] is the timestamp of the last local edit, or null if never edited.
class Quote {
  final String id;
  final String text;
  final String? author;

  // v2 fields — optional to preserve backward-compat const construction
  final List<String> tags;
  final QuoteSource source;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Quote({
    required this.id,
    required this.text,
    this.author,
    this.tags = const [],
    this.source = QuoteSource.seeded,
    this.createdAt,
    this.updatedAt,
  });

  /// Two quotes are equal if they share the same [id].
  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Quote && other.id == id);

  @override
  int get hashCode => id.hashCode;

  /// Serializes this quote to a map suitable for sqflite insertion.
  ///
  /// When [createdAt] is null (v1-style construction), only the three v1
  /// columns are emitted so that old-style quotes produce a 3-key map.
  ///
  /// When [createdAt] is non-null, all seven v2 columns are emitted.
  Map<String, Object?> toMap() {
    if (createdAt == null) {
      // v1-compatible output — 3 keys only
      return {
        'id': id,
        'text': text,
        'author': author,
      };
    }
    // Full v2 output — 7 keys
    return {
      'id': id,
      'text': text,
      'author': author,
      'tags': jsonEncode(tags),
      'source': source.name,
      'created_at': createdAt!.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Deserializes a sqflite row map into a [Quote].
  ///
  /// Backward-compatible: handles v1 rows that are missing [tags], [source],
  /// [created_at], and [updated_at] columns by applying safe defaults.
  factory Quote.fromMap(Map<String, Object?> row) {
    // Backward-compatible deserialization of v2 fields
    final tagsRaw = row['tags'] as String?;
    final List<String> tags =
        tagsRaw != null ? List<String>.from(jsonDecode(tagsRaw) as List) : [];

    final sourceRaw = row['source'] as String?;
    final QuoteSource source = sourceRaw != null
        ? QuoteSource.values.firstWhere(
            (e) => e.name == sourceRaw,
            orElse: () => QuoteSource.seeded,
          )
        : QuoteSource.seeded;

    final createdAtRaw = row['created_at'] as String?;
    // Fallback for missing or empty created_at (v1 rows or ALTER TABLE default '')
    final DateTime createdAt = (createdAtRaw != null && createdAtRaw.isNotEmpty)
        ? DateTime.parse(createdAtRaw)
        : DateTime.utc(2026, 3, 27); // deterministic migration fallback

    final updatedAtRaw = row['updated_at'] as String?;
    final DateTime? updatedAt =
        (updatedAtRaw != null && updatedAtRaw.isNotEmpty)
            ? DateTime.parse(updatedAtRaw)
            : null;

    return Quote(
      id: row['id'] as String,
      text: row['text'] as String,
      author: row['author'] as String?,
      tags: tags,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() =>
      'Quote(id: $id, author: $author, source: ${source.name}, '
      'text: ${text.substring(0, text.length.clamp(0, 40))}...)';
}
