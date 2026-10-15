import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bio_flutter/bio_flutter.dart';
import 'package:bio_flutter/src/structure/scene/orbit_camera.dart';
import 'package:bio_flutter/src/structure/scene/viewer_scene.dart';
import 'package:vector_math/vector_math.dart' show Vector3;

const a = ResidueKey('A', ResidueId(10, ''));
const b = ResidueKey('B', ResidueId(10, ''));

MolecularStructure structure() => MolecularStructure(
  chains: [
    for (final id in ['A', 'B'])
      Chain(
        id: id,
        authChainId: 'X',
        residues: [
          Residue(
            id: const ResidueId(10, ''),
            name: 'ALA',
            secondaryStructure: SecondaryStructureType.loop,
            atoms: [
              Atom(
                serial: 1,
                element: 'C',
                atomName: 'CA',
                position: Vector3.zero(),
                occupancy: 1,
                bFactor: 0,
                isHeteroRecord: false,
              ),
            ],
          ),
        ],
      ),
  ],
);

class FakeScene implements ViewerScene {
  Set<ResidueKey> selection = {};
  Map<ResidueKey, Color> highlights = {};
  CartoonStyle? style;
  ResidueKey? hit = a;
  OrbitCameraController? camera;
  bool disposed = false;

  @override
  Widget view(OrbitCameraController camera) {
    this.camera = camera;
    return const ColoredBox(color: Colors.black, child: SizedBox.expand());
  }

  @override
  ResidueKey? pick(Offset position, Size size, OrbitCameraController camera) =>
      hit;

  @override
  void updateAppearance(
    CartoonStyle style,
    Set<ResidueKey> selection,
    Map<ResidueKey, Color> highlights,
    ResidueKey? hover,
  ) {
    this.style = style;
    this.selection = Set.of(selection);
    this.highlights = Map.of(highlights);
  }

  @override
  void dispose() => disposed = true;
}

void main() {
  late FakeScene scene;
  late MolecularStructure molecule;
  late ViewerSceneFactory factory;
  late int creates;

  setUp(() {
    scene = FakeScene();
    molecule = structure();
    creates = 0;
    factory = (_) async {
      creates++;
      return scene;
    };
  });

  Widget host(ProteinViewer viewer, {ViewerSceneFactory? create}) =>
      MaterialApp(
        home: ViewerSceneScope(
          create: create ?? factory,
          child: SizedBox(width: 500, height: 400, child: viewer),
        ),
      );

  testWidgets(
    'standalone selection changes internally and background clears it',
    (tester) async {
      final changes = <Set<ResidueKey>>[];
      await tester.pumpWidget(
        host(
          ProteinViewer(structure: molecule, onSelectionChanged: changes.add),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ProteinViewer));
      expect(scene.selection, {a});
      expect(changes, [
        {a},
      ]);
      scene.hit = null;
      await tester.tap(find.byType(ProteinViewer));
      expect(scene.selection, isEmpty);
      expect(changes.last, isEmpty);
    },
  );

  testWidgets(
    'controlled clicks propose changes without changing supplied selection',
    (tester) async {
      final changes = <Set<ResidueKey>>[];
      await tester.pumpWidget(
        host(
          ProteinViewer(
            structure: molecule,
            selectedResidues: {b},
            onSelectionChanged: changes.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ProteinViewer));
      expect(scene.selection, {b});
      expect(changes, [
        {a},
      ]);
      await tester.pumpWidget(
        host(
          ProteinViewer(
            structure: molecule,
            selectedResidues: {a, b},
            onSelectionChanged: changes.add,
          ),
        ),
      );
      expect(scene.selection, {a, b});
      expect(changes, hasLength(1));
      expect(creates, 1);
    },
  );

  testWidgets('annotations and styles preserve camera and scene', (
    tester,
  ) async {
    await tester.pumpWidget(host(ProteinViewer(structure: molecule)));
    await tester.pumpAndSettle();
    final camera = scene.camera!;
    camera.orbit(0.5, 0.2);
    final position = camera.buildCamera().position.clone();
    await tester.pumpWidget(
      host(
        ProteinViewer(
          structure: molecule,
          highlights: {a: Colors.purple},
          style: const CartoonStyle(helixColor: Colors.blue),
        ),
      ),
    );
    expect(scene.highlights[a], Colors.purple);
    expect(scene.style!.helixColor, Colors.blue);
    expect(scene.camera, same(camera));
    expect(camera.buildCamera().position, position);
    expect(creates, 1);
  });

  testWidgets('shift-click toggles multi-selection and drags do not select', (
    tester,
  ) async {
    await tester.pumpWidget(host(ProteinViewer(structure: molecule)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ProteinViewer));
    scene.hit = b;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tap(find.byType(ProteinViewer));
    expect(scene.selection, {a, b});
    await tester.tap(find.byType(ProteinViewer));
    expect(scene.selection, {a});
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.drag(find.byType(ProteinViewer), const Offset(80, 0));
    expect(scene.selection, {a});
  });

  testWidgets(
    'releasing control retains selection; a new structure resets internal state',
    (tester) async {
      await tester.pumpWidget(
        host(ProteinViewer(structure: molecule, selectedResidues: {b})),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(host(ProteinViewer(structure: molecule)));
      expect(scene.selection, {b});
      final old = scene;
      scene = FakeScene();
      await tester.pumpWidget(host(ProteinViewer(structure: structure())));
      await tester.pumpAndSettle();
      expect(old.disposed, isTrue);
      expect(scene.selection, isEmpty);
    },
  );

  testWidgets('stale initialization cannot replace a newer structure', (
    tester,
  ) async {
    final first = Completer<ViewerScene>();
    final second = Completer<ViewerScene>();
    var request = 0;
    Future<ViewerScene> pending(MolecularStructure _) =>
        request++ == 0 ? first.future : second.future;
    await tester.pumpWidget(
      host(ProteinViewer(structure: molecule), create: pending),
    );
    await tester.pumpWidget(
      host(ProteinViewer(structure: structure()), create: pending),
    );
    second.complete(scene);
    await tester.pumpAndSettle();
    final stale = FakeScene();
    first.complete(stale);
    await tester.pumpAndSettle();
    expect(stale.disposed, isTrue);
    expect(scene.disposed, isFalse);
  });

  testWidgets('unmount during initialization releases the eventual result', (
    tester,
  ) async {
    final pending = Completer<ViewerScene>();
    await tester.pumpWidget(
      host(ProteinViewer(structure: molecule), create: (_) => pending.future),
    );
    await tester.pumpWidget(const SizedBox());
    pending.complete(scene);
    await tester.pumpAndSettle();
    expect(scene.disposed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'controller replacement detaches old controller and supports focus',
    (tester) async {
      final old = ProteinViewerController();
      final next = ProteinViewerController();
      expect(old.resetCamera(), isFalse);
      await tester.pumpWidget(
        host(ProteinViewer(structure: molecule, controller: old)),
      );
      await tester.pumpAndSettle();
      expect(old.focusResidue(a), isTrue);
      expect(old.focusChain('missing'), isFalse);
      await tester.pumpWidget(
        host(ProteinViewer(structure: molecule, controller: next)),
      );
      expect(old.isAttached, isFalse);
      expect(next.resetCamera(), isTrue);
      await tester.pumpWidget(const SizedBox());
      expect(next.isAttached, isFalse);
      old.dispose();
      next.dispose();
    },
  );

  testWidgets('empty structure needs no renderer', (tester) async {
    await tester.pumpWidget(
      host(ProteinViewer(structure: MolecularStructure(chains: []))),
    );
    expect(find.text('No amino acid coordinates.'), findsOneWidget);
    expect(creates, 0);
  });

  testWidgets('initialization errors reach the custom error builder', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        ProteinViewer(
          structure: molecule,
          errorBuilder: (_, error) => Text('failure: $error'),
        ),
        create: (_) async => throw StateError('GPU unavailable'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('GPU unavailable'), findsOneWidget);
  });
}
