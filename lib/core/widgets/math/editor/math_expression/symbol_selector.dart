import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart' as math_fork;

import 'utils/constants.dart';

class SymbolSelector extends StatefulWidget {
  final String searchQuery;
  final ValueChanged<String> updateSearchQuery;
  final bool showSuggestions;
  final List<String> suggestions;
  final ValueChanged<String> onSymbolSelected;

  const SymbolSelector({
    super.key,
    required this.searchQuery,
    required this.updateSearchQuery,
    required this.showSuggestions,
    required this.suggestions,
    required this.onSymbolSelected,
  });

  @override
  State<SymbolSelector> createState() => _SymbolSelectorState();
}

class _SymbolSelectorState extends State<SymbolSelector>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String selectedCategory = '';

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: Constants.symbolCategories.length, vsync: this);
    selectedCategory = Constants.symbolCategories.first;
    _tabController.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      setState(() {
        selectedCategory = Constants.symbolCategories[_tabController.index];
      });
    }
  }

  List<String> _filterSymbols(List<String> symbols, String query) {
    if (query.isEmpty) return symbols;
    return symbols.where((symbol) {
      final lowerQuery = query.toLowerCase();
      final symbolName =
          symbol.replaceAll('\\', '').replaceAll('{}', '').toLowerCase();
      return symbolName.contains(lowerQuery);
    }).toList();
  }

  Widget _buildSymbolButton(String symbol, double fontSize, Size buttonSize) {
    return Tooltip(
      message:
          Constants.symbolDescriptions[symbol] ?? symbol.replaceAll(r'\', ''),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6.0),
          onTap: () {
            widget.onSymbolSelected(symbol);
          },
          child: Container(
            width: buttonSize.width,
            height: buttonSize.height,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: Center(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: math_fork.Math.tex(
                    symbol,
                    textStyle: TextStyle(fontSize: fontSize),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = _calculateCrossAxisCount(screenWidth);
    const childAspectRatio = 1.0;
    const fontSize = 14.0;
    const buttonSize = Size(40, 40);

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 13),
          tabs: Constants.symbolCategories
              .map((category) => Tab(text: category))
              .toList(),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search symbols...',
              prefixIcon: Icon(Icons.search, size: 20),
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            onChanged: widget.updateSearchQuery,
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: Constants.symbolCategories.map((category) {
              final symbols = Constants.symbols[category] ?? [];
              final filteredSymbols =
                  _filterSymbols(symbols, widget.searchQuery);

              return GridView.builder(
                padding: const EdgeInsets.all(12.0),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: 10.0,
                  mainAxisSpacing: 10.0,
                ),
                itemCount: filteredSymbols.length,
                itemBuilder: (context, index) => _buildSymbolButton(
                  filteredSymbols[index],
                  fontSize,
                  buttonSize,
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  int _calculateCrossAxisCount(double width) {
    if (width > 1200) return 14;
    if (width > 900) return 12;
    if (width > 600) return 10;
    return 8;
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    super.dispose();
  }
}
