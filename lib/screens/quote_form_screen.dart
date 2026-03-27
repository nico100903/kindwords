import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/quote.dart';
import '../providers/quote_catalog_provider.dart';

/// Predefined tags available for selection when creating a quote.
const List<String> _kFormTags = [
  'motivational',
  'wisdom',
  'humor',
  'love',
  'focus',
  'personal',
];

/// The Quote Form screen — create mode only (task 07.01).
///
/// Uses a [Form] with a [GlobalKey<FormState>] for validation.
/// Owns [TextEditingController] instances that are disposed in [dispose].
/// Selected tags are held in a [Set<String>] as local UI state.
///
/// On successful save:
/// 1. Validates the form.
/// 2. Builds a [Quote] with source [QuoteSource.userCreated].
/// 3. Calls [QuoteCatalogProvider.createQuote].
/// 4. Pops with result `true` so the caller can refresh.
class QuoteFormScreen extends StatefulWidget {
  const QuoteFormScreen({super.key});

  @override
  State<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends State<QuoteFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();

  final Set<String> _selectedTags = {};
  bool _isSaving = false;

  @override
  void dispose() {
    _textController.dispose();
    _authorController.dispose();
    super.dispose();
  }

  // ── Save action ─────────────────────────────────────────────────────────────

  Future<void> _onSave() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);

    final quote = Quote(
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

    try {
      await context.read<QuoteCatalogProvider>().createQuote(quote);
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

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(final BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool maxTagsReached = _selectedTags.length >= 3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Quote'),
        leading: IconButton(
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
                  child: const Text('Save'),
                ),
        ],
      ),
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
              const ListTile(
                enabled: false,
                leading: Icon(Icons.edit_note),
                title: Text('Your own quote'),
                contentPadding: EdgeInsets.zero,
              ),
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
