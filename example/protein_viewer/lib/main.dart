import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:bio_flutter/bio_flutter.dart';

void main() => runApp(const ViewerExample());

class ViewerExample extends StatelessWidget {
  const ViewerExample({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Protein viewer',
    theme: ThemeData.dark(useMaterial3: true),
    home: const StructurePage(),
  );
}

class StructurePage extends StatefulWidget {
  const StructurePage({super.key});

  @override
  State<StructurePage> createState() => _StructurePageState();
}

class _StructurePageState extends State<StructurePage> {
  final _controller = ProteinViewerController();
  MmcifParseResult? _result;
  Object? _error;
  Set<ResidueKey> _selection = {};
  Map<ResidueKey, Color> _highlights = {};
  ResidueHit? _hover;
  bool _linked = true;
  bool _outline = false;
  bool _pencil = false;
  String _fixture = '2QLE';
  int _request = 0;

  static const _fixtures = {
    '2QLE': 'assets/2QLE.cif',
    '2GBP': 'assets/2GBP.cif',
    'Myoglobin': 'assets/AF-P02185-F1-myoglobin-no-ss.cif',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _result = null;
      _error = null;
      _selection = {};
      _highlights = {};
      _hover = null;
    });
    try {
      final text = await rootBundle.loadString(_fixtures[_fixture]!);
      final result = await MmcifParser.parse(text);
      if (!mounted || request != _request) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('Protein viewer')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                DropdownButton<String>(
                  value: _fixture,
                  items: [
                    for (final name in _fixtures.keys)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    _fixture = value;
                    _load();
                  },
                ),
                FilterChip(
                  label: const Text('Link sequence selection'),
                  selected: _linked,
                  onSelected: (value) => setState(() => _linked = value),
                ),
                FilterChip(
                  label: const Text('Outlines'),
                  selected: _outline,
                  onSelected: (value) => setState(() => _outline = value),
                ),
                FilterChip(
                  label: const Text('Pencil'),
                  selected: _pencil,
                  onSelected: (value) => setState(() => _pencil = value),
                ),
                TextButton(
                  onPressed: () => _controller.resetCamera(),
                  child: const Text('Reset camera'),
                ),
                TextButton(
                  onPressed: _selection.isEmpty
                      ? null
                      : () => setState(() {
                          _highlights = {
                            ..._highlights,
                            for (final key in _selection)
                              key: Colors.purpleAccent,
                          };
                          _selection = {};
                        }),
                  child: const Text('Annotate selected'),
                ),
                TextButton(
                  onPressed: () => setState(() => _highlights = {}),
                  child: const Text('Clear annotations'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _error != null
                ? Center(child: Text('Loading failed: $_error'))
                : result == null
                ? const Center(child: CircularProgressIndicator())
                : ProteinViewer(
                    structure: result.structure,
                    controller: _controller,
                    selectedResidues: _linked ? _selection : null,
                    highlights: _highlights,
                    style: CartoonStyle(
                      outlineColor: _outline ? Colors.black : null,
                      pencilTexture: _pencil,
                    ),
                    onSelectionChanged: (next) =>
                        setState(() => _selection = next),
                    onResidueHover: (hit) => setState(() => _hover = hit),
                    errorBuilder: (_, error) => Center(
                      child: SelectableText('Renderer failed: $error'),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              _hover == null
                  ? '${_selection.length} selected · Drag to rotate · Shift-click to add · Scroll to zoom'
                  : '${_hover!.chain.authChainId} / ${_hover!.name} ${_hover!.key.residueId}',
            ),
          ),
          if (result != null)
            SizedBox(
              height: 160,
              child: ListView(
                children: [
                  for (final chain in result.structure.chains)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chain ${chain.authChainId} (ID ${chain.id})'),
                          Wrap(
                            spacing: 4,
                            children: [
                              for (final residue in chain.residues)
                                _residueChip(chain, residue),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          if (result != null && result.diagnostics.isNotEmpty)
            ExpansionTile(
              title: Text('${result.diagnostics.length} parsing warnings'),
              children: [
                SizedBox(
                  height: 100,
                  child: ListView(
                    children: [
                      for (final diagnostic in result.diagnostics)
                        Text(diagnostic.message),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _residueChip(Chain chain, Residue residue) {
    final key = ResidueKey(chain.id, residue.id);
    return FilterChip(
      label: Text('${residue.name} ${residue.id}'),
      selected: _selection.contains(key),
      onSelected: !_linked
          ? null
          : (selected) => setState(() {
              _selection = {..._selection};
              if (selected) {
                _selection.add(key);
              } else {
                _selection.remove(key);
              }
            }),
    );
  }
}
