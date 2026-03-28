import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/quote.dart';
import '../providers/quote_catalog_provider.dart';

/// Predefined tags available for selection when creating or editing a quote.
const List<String> _kFormTags = [
  'motivational',
  'wisdom',
  'humor',
  'love',
  'focus',
  'personal',
];

/// The Quote Form screen — supports both create mode (task 07.01) and
/// edit mode (task 07.02).
///
/// **Create mode:** `quote == null`
///   - AppBar shows "New Quote" title and ✕ close button.
///   - Action button is "Save".
///   - No delete section visible.
///   - On save: builds a [Quote] with [QuoteSource.userCreated] and a new id.
///
/// **Edit mode:** `quote != null`
///   - AppBar shows "Edit Quote" title and ← back button.
///   - Action button is "Update".
///   - Delete section is visible below a [Divider].
///   - On update: preserves original [Quote.id], [Quote.createdAt], and
///     [Quote.source]; sets [Quote.updatedAt] to the current time.
///   - On delete: shows [AlertDialog] confirmation before removing.
///
/// Uses a [Form] with a [GlobalKey<FormState>] for validation.
/// Owns [TextEditingController] instances that are disposed in [dispose].
/// Selected tags are held in a [Set<String>] as local UI state.
class QuoteFormScreen extends StatefulWidget {
  /// The existing quote to edit. When null, the screen operates in create mode.
  final Quote? quote;

  const QuoteFormScreen({super.key, this.quote});

  @override
  State<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends State<QuoteFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _textController;
  late final TextEditingController _authorController;

  late final Set<String> _selectedTags;
  bool _isSaving = false;

  bool get _isEditMode => widget.quote != null;

  @override
  void initState() {
    super.initState();
    final Quote? q = widget.quote;
    _textController = TextEditingController(text: q?.text ?? '');
    _authorController = TextEditingController(text: q?.author ?? '');
    _selectedTags = q != null ? Set<String>.from(q.tags) : {};
  }

  @override
  void dispose() {
    _textController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  // ── Save / Update action ─────────────────────────────────────────────────────

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final Quote quote;

    if (_isEditMode) {
      // Edit mode — preserve id, createdAt, source; set updatedAt
      final Quote original = widget.quote!;
      quote = Quote(
        id: original.id,
        text: _textController.text.trim(),
        author: _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        tags: _selectedTags.toList(),
        source: original.source,
        createdAt: original.createdAt,
        updatedAt: DateTime.now(),
      );
    } else {
      // Create mode
      quote = Quote(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        text: _textController.text.trim(),
        author: _authorController.text.trim().isEmpty
            ? null
            : _authorController.text.trim(),
        tags: _selectedTags.toList(),
        source: QuoteSource.userCreated,
        createdAt: DateTime.now(),
        updatedAt: null,
      );
    }

    try {
      if (_isEditMode) {
        await context.read<QuoteCatalogProvider>().updateQuote(quote);
      } else {
        await context.read<QuoteCatalogProvider>().createQuote(quote);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save quote. Please try again.'),
          ),
        );
      }
    }
  }

  // ── Delete action ────────────────────────────────────────────────────────────

  Future<void> _onDelete() async {
    final Quote original = widget.quote!;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (final BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Delete Quote?'),
          content: Text(
            'Quote text: "${original.text.length > 60 ? '${original.text.substring(0, 60)}…' : original.text}" '
            'will be permanently removed from your local collection.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await context.read<QuoteCatalogProvider>().deleteQuote(original.id);
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  // ── Tag selection ────────────────────────────────────────────────────────────

  void _onTagToggle(final String tag, final bool selected) {
    setState(() {
      if (selected) {
        _selectedTags.add(tag);
      } else {
        _selectedTags.remove(tag);
      }
    });
  }

  // ── Source indicator ─────────────────────────────────────────────────────────

  Widget _buildSourceIndicator(final BuildContext context) {
    if (_isEditMode) {
      final Quote original = widget.quote!;
      final bool isSeeded = original.source == QuoteSource.seeded;
      return ListTile(
        enabled: false,
        leading: Icon(isSeeded ? Icons.menu_book_outlined : Icons.edit_note),
        title: Text(isSeeded ? 'From bundled catalog' : 'Your own quote'),
        contentPadding: EdgeInsets.zero,
      );
    }
    // Create mode — always userCreated
    return const ListTile(
      enabled: false,
      leading: Icon(Icons.edit_note),
      title: Text('Your own quote'),
      contentPadding: EdgeInsets.zero,
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(final BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool maxTagsReached = _selectedTags.length >= 3;

    final String title = _isEditMode ? 'Edit Quote' : 'New Quote';
    final String actionLabel = _isEditMode ? 'Update' : 'Save';

    // Edit mode: show delete section as a persistent bottom bar so the button
    // is always visible in the viewport regardless of scroll position.
    // The Divider at the top of the bottom bar satisfies the spec requirement
    // that the delete button appears "below a Divider".
    final Widget? deleteBar = _isEditMode
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Center(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                    onPressed: _onDelete,
                    child: const Text('Delete this quote'),
                  ),
                ),
              ),
            ],
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: _isEditMode
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
                onPressed: () => Navigator.of(context).pop(false),
              )
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Discard',
                onPressed: () => Navigator.of(context).pop(false),
              ),
        actions: [
          _isSaving
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _onSave,
                  child: Text(actionLabel),
                ),
        ],
      ),
      bottomNavigationBar: deleteBar,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Quote text field ─────────────────────────────────────────
              Text(
                'QUOTE TEXT',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _textController,
                minLines: 4,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                decoration: const InputDecoration(
                  labelText: 'Quote text',
                  hintText: "What's on your mind?",
                  border: OutlineInputBorder(),
                ),
                validator: (final String? value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Quote text is required.';
                  }
                  if (value.trim().length < 10) {
                    return 'Quote must be at least 10 characters.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ── Author field ─────────────────────────────────────────────
              Text(
                'AUTHOR (optional)',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _authorController,
                inputFormatters: [LengthLimitingTextInputFormatter(100)],
                decoration: const InputDecoration(
                  labelText: 'Author',
                  hintText: 'Who said this? (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // ── Tag chips ────────────────────────────────────────────────
              Text(
                'TAGS (optional — pick up to 3)',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 8),
              _TagSelector(
                tags: _kFormTags,
                selectedTags: _selectedTags,
                maxTagsReached: maxTagsReached,
                colorScheme: colorScheme,
                onToggle: _onTagToggle,
              ),
              const SizedBox(height: 20),

              // ── Source indicator (read-only) ─────────────────────────────
              Text(
                'SOURCE',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              const SizedBox(height: 4),
              _buildSourceIndicator(context),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tag selector widget
// ---------------------------------------------------------------------------

class _TagSelector extends StatelessWidget {
  final List<String> tags;
  final Set<String> selectedTags;
  final bool maxTagsReached;
  final ColorScheme colorScheme;
  final void Function(String tag, bool selected) onToggle;

  const _TagSelector({
    required this.tags,
    required this.selectedTags,
    required this.maxTagsReached,
    required this.colorScheme,
    required this.onToggle,
  });

  @override
  Widget build(final BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: tags.map<Widget>((final String tag) {
        final bool isSelected = selectedTags.contains(tag);
        final bool isDisabled = maxTagsReached && !isSelected;

        return Semantics(
          label: 'Tag: $tag${isSelected ? ', selected' : ''}',
          child: FilterChip(
            label: Text('#$tag'),
            selected: isSelected,
            selectedColor: colorScheme.primaryContainer,
            onSelected:
                isDisabled ? null : (final bool sel) => onToggle(tag, sel),
          ),
        );
      }).toList(),
    );
  }
}
