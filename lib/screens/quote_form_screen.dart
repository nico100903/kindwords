/// STUB: QuoteFormScreen for create/edit flows.
///
/// This is a placeholder created by QA for BDD tests in task 07.01.
/// The coder must implement the full form per task specification.
///
/// DO NOT MODIFY THIS FILE - it exists only to allow tests to compile.
/// The implementation belongs in a separate task.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/quote_catalog_provider.dart';

/// Quote form screen for create and edit flows.
///
/// In create mode (default), allows user to enter a new quote.
/// In edit mode (when quote is passed), allows editing existing quote.
///
/// STUB IMPLEMENTATION - coder must implement per task 07.01 spec.
class QuoteFormScreen extends StatefulWidget {
  /// The quote to edit, or null for create mode.
  final dynamic quote; // Quote type, using dynamic to avoid import issues

  const QuoteFormScreen({super.key, this.quote});

  @override
  State<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _QuoteFormScreenState extends State<QuoteFormScreen> {
  @override
  Widget build(BuildContext context) {
    // STUB: returns empty scaffold - tests will fail
    // Coder must implement full form UI
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quote Form'),
      ),
      body: const Center(
        child: Text('STUB - Not implemented'),
      ),
    );
  }
}
