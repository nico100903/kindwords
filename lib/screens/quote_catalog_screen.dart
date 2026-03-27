import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/quote.dart';
import '../providers/quote_catalog_provider.dart';

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

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Quotes'),
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
              Expanded(child: _QuoteList(provider: provider)),
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

  const _QuoteList({required this.provider});

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
        return _QuoteListTile(quote: quotes[index]);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Quote list tile
// ---------------------------------------------------------------------------

class _QuoteListTile extends StatelessWidget {
  final Quote quote;

  const _QuoteListTile({required this.quote});

  @override
  Widget build(final BuildContext context) {
    final bool isSeeded = quote.source == QuoteSource.seeded;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(
        isSeeded ? Icons.menu_book_outlined : Icons.edit_note,
        color: isSeeded ? colorScheme.primary : colorScheme.secondary,
      ),
      title: Builder(
        builder: (final BuildContext ctx) => RichText(
          text: TextSpan(
            text: quote.text,
            style: DefaultTextStyle.of(ctx).style,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      subtitle: _SubtitleWidget(quote: quote),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit quote',
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete quote',
            onPressed: () {},
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
    final String authorLine =
        quote.author != null ? '— ${quote.author}' : 'Anonymous';

    if (quote.tags.isEmpty) {
      return Text(authorLine);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(authorLine),
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
