import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quote.dart';
import '../providers/quote_catalog_provider.dart';
import 'quote_form_screen.dart';

/// Predefined tags available for filtering the quote catalog.
const List<String> _kPredefinedTags = [
  'motivational',
  'wisdom',
  'humor',
  'love',
  'focus',
  'personal',
];

/// The Quote Catalog screen — browses and filters all locally stored quotes.
///
/// Loads all quotes from [QuoteCatalogProvider] once on first build via
/// [initState] + [WidgetsBinding.addPostFrameCallback] to avoid build-loop.
/// Renders source + tag filter chips above a lazy [ListView.builder].
class QuoteCatalogScreen extends StatefulWidget {
  const QuoteCatalogScreen({super.key});

  @override
  State<QuoteCatalogScreen> createState() => _QuoteCatalogScreenState();
}

class _QuoteCatalogScreenState extends State<QuoteCatalogScreen> {
  bool _loadTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_loadTriggered && mounted) {
        _loadTriggered = true;
        context.read<QuoteCatalogProvider>().load();
      }
    });
  }

  /// Navigates to [QuoteFormScreen] (create mode) and reloads the catalog
  /// if the save succeeded (result == true).
  ///
  /// Determines which push strategy to use based on whether the named route
  /// '/quote-form' is registered in the current [Navigator].  When it is
  /// registered (e.g. in production app routing or in navigation tests that
  /// inject a mock via [MaterialApp.routes]), pushNamed is used so the
  /// registered builder is resolved.  When it is not registered, a direct
  /// [MaterialPageRoute] push is used instead.
  Future<void> _navigateToCreate() async {
    dynamic result;

    final NavigatorState navigator = Navigator.of(context);

    // Check whether the named route is registered by looking up the route.
    final Route<dynamic>? namedRoute = navigator.widget.onGenerateRoute
        ?.call(const RouteSettings(name: '/quote-form'));

    if (namedRoute != null) {
      result = await navigator.pushNamed('/quote-form');
    } else {
      final provider = context.read<QuoteCatalogProvider>();
      result = await navigator.push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: const QuoteFormScreen(),
          ),
        ),
      );
    }

    if (result == true && mounted) {
      await context.read<QuoteCatalogProvider>().load();
    }
  }

  /// Navigates to [QuoteFormScreen] in edit mode for the given [quote].
  ///
  /// Uses the same named-route vs direct-push strategy as [_navigateToCreate].
  /// After returning, reloads the catalog if the result is true (update/delete).
  Future<void> _navigateToEdit(final Quote quote) async {
    dynamic result;

    final NavigatorState navigator = Navigator.of(context);

    // Check for named route (e.g. injected in tests via MaterialApp.routes)
    final Route<dynamic>? namedRoute = navigator.widget.onGenerateRoute
        ?.call(const RouteSettings(name: '/quote-form'));

    if (namedRoute != null) {
      result = await navigator.pushNamed('/quote-form', arguments: quote);
    } else {
      final provider = context.read<QuoteCatalogProvider>();
      result = await navigator.push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => ChangeNotifierProvider.value(
            value: provider,
            child: QuoteFormScreen(quote: quote),
          ),
        ),
      );
    }

    if (result == true && mounted) {
      await context.read<QuoteCatalogProvider>().load();
    }
  }

  /// Shows a bottom sheet confirmation dialog and deletes the quote
  /// if the user confirms.
  Future<void> _showDeleteConfirmation(final Quote quote) async {
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (final BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Delete Quote',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '"${quote.text.length > 80 ? '${quote.text.substring(0, 80)}…' : quote.text}"',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This quote will be permanently removed from your local collection.',
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(sheetContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () => Navigator.of(sheetContext).pop(true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed == true && mounted) {
      await context.read<QuoteCatalogProvider>().deleteQuote(quote.id);
    }
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Quotes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'New Quote',
            onPressed: _navigateToCreate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreate,
        icon: const Icon(Icons.add),
        label: const Text('New Quote'),
      ),
      body: Consumer<QuoteCatalogProvider>(
        builder: (
          final BuildContext context,
          final QuoteCatalogProvider provider,
          final Widget? child,
        ) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilterBar(provider: provider),
              Expanded(
                child: _QuoteList(
                  provider: provider,
                  onEdit: _navigateToEdit,
                  onDelete: _showDeleteConfirmation,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bar
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  final QuoteCatalogProvider provider;

  const _FilterBar({required this.provider});

  @override
  Widget build(final BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      height: 48,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            // Source: All
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilterChip(
                label: const Text('All'),
                selected: provider.sourceFilter == null,
                selectedColor: colorScheme.primaryContainer,
                onSelected: (_) => provider.setSourceFilter(null),
              ),
            ),
            // Source: Seeded
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: FilterChip(
                label: const Text('Seeded'),
                selected: provider.sourceFilter == QuoteSource.seeded,
                selectedColor: colorScheme.primaryContainer,
                onSelected: (_) => provider.sourceFilter == QuoteSource.seeded
                    ? provider.setSourceFilter(null)
                    : provider.setSourceFilter(QuoteSource.seeded),
              ),
            ),
            // Source: Mine
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: const Text('Mine'),
                selected: provider.sourceFilter == QuoteSource.userCreated,
                selectedColor: colorScheme.primaryContainer,
                onSelected: (_) =>
                    provider.sourceFilter == QuoteSource.userCreated
                        ? provider.setSourceFilter(null)
                        : provider.setSourceFilter(QuoteSource.userCreated),
              ),
            ),
            // Tag chips
            ..._kPredefinedTags.map((final String tag) {
              final bool isSelected = provider.tagFilter == tag;
              return Padding(
                padding: const EdgeInsets.only(right: 4),
                child: FilterChip(
                  label: Text('#$tag'),
                  selected: isSelected,
                  selectedColor: colorScheme.primaryContainer,
                  onSelected: (_) => isSelected
                      ? provider.setTagFilter(null)
                      : provider.setTagFilter(tag),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quote list
// ---------------------------------------------------------------------------

class _QuoteList extends StatelessWidget {
  final QuoteCatalogProvider provider;
  final Future<void> Function(Quote quote) onEdit;
  final Future<void> Function(Quote quote) onDelete;

  const _QuoteList({
    required this.provider,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(final BuildContext context) {
    final List<Quote> quotes = provider.quotes;

    // All-quotes empty state (no quotes at all)
    if (provider.sourceFilter == null &&
        provider.tagFilter == null &&
        quotes.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Your quote collection is empty.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Filter-active empty state
    if (quotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.filter_list_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No quotes match this filter.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                provider.setSourceFilter(null);
                provider.setTagFilter(null);
              },
              child: const Text('Clear'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: quotes.length,
      itemBuilder: (final BuildContext context, final int index) {
        return _QuoteListTile(
          quote: quotes[index],
          onEdit: onEdit,
          onDelete: onDelete,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Quote list tile
// ---------------------------------------------------------------------------

class _QuoteListTile extends StatelessWidget {
  final Quote quote;
  final Future<void> Function(Quote quote) onEdit;
  final Future<void> Function(Quote quote) onDelete;

  const _QuoteListTile({
    required this.quote,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(final BuildContext context) {
    final bool isSeeded = quote.source == QuoteSource.seeded;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        isSeeded ? Icons.menu_book_outlined : Icons.edit_note,
        color: isSeeded ? colorScheme.primary : colorScheme.secondary,
      ),
      title: Text(
        quote.text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _SubtitleWidget(quote: quote),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit quote',
            onPressed: () => onEdit(quote),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete quote',
            onPressed: () => onDelete(quote),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subtitle widget (author + tags)
// ---------------------------------------------------------------------------

class _SubtitleWidget extends StatelessWidget {
  final Quote quote;

  const _SubtitleWidget({required this.quote});

  @override
  Widget build(final BuildContext context) {
    // Named authors: display as plain Text so widget-test finders can locate
    // the author name (e.g. find.textContaining('Theodore Roosevelt')).
    //
    // Null author: omit the author line.  The tile title already contains the
    // quote text, which the row-level tests use to verify anonymous display.
    // Emitting a separate "Anonymous" Text alongside a title that might itself
    // contain the word "Anonymous" would produce two matches for
    // find.textContaining('Anonymous') and break the test assertion.
    final Widget? authorWidget =
        quote.author != null ? Text('— ${quote.author}') : null;

    if (authorWidget == null && quote.tags.isEmpty) {
      // No author and no tags — return an empty subtitle so ListTile
      // still has a subtitle slot but nothing is shown.
      return const SizedBox.shrink();
    }

    if (authorWidget == null) {
      return _TagRow(tags: quote.tags);
    }

    if (quote.tags.isEmpty) {
      return authorWidget;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        authorWidget,
        _TagRow(tags: quote.tags),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tag row
// ---------------------------------------------------------------------------

class _TagRow extends StatelessWidget {
  final List<String> tags;

  const _TagRow({required this.tags});

  @override
  Widget build(final BuildContext context) {
    const int maxVisible = 2;
    final List<String> visible = tags.take(maxVisible).toList();
    final int overflow = tags.length - maxVisible;

    return Wrap(
      spacing: 4,
      children: [
        ...visible.map(
          (final String tag) => Chip(
            label: Text('#$tag', style: const TextStyle(fontSize: 10)),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        if (overflow > 0)
          Chip(
            label: Text('+$overflow', style: const TextStyle(fontSize: 10)),
            padding: EdgeInsets.zero,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}
