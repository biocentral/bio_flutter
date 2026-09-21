# Protein structure viewer

A Flutter cartoon viewer for amino acid chains in mmCIF files. Embed it in an application, use its standalone selection, or connect it to a sequence viewer through shared residue keys.

The viewer is exported by `package:bio_flutter/bio_flutter.dart` and by the focused
`package:bio_flutter/protein_viewer.dart` entry point. Flutter requirements apply
to the entire package, regardless of which entry point is imported. The example
contains Dart sources and fixtures only; consuming applications provide their own
platform runners.

## Quick start

Use a path dependency while developing:

```yaml
dependencies:
  bio_flutter:
    path: ../bio_flutter
```

Load mmCIF text using your application's asset, file, or HTTP APIs, then parse it once outside `build`:

```dart
import 'package:bio_flutter/bio_flutter.dart';

final result = await MmcifParser.parse(cifText);
```

Give the viewer bounded dimensions:

```dart
Expanded(
  child: ProteinViewer(structure: result.structure),
)
```

The viewer initializes Scene resources, creates the cartoon, frames the camera, and owns the interaction state. Applications do not need to import Flutter Scene or construct meshes, picking proxies, or cameras. Native applications still need the runner configuration described in [platform setup](platforms.md).

## Shared selection and annotations

```dart
ProteinViewer(
  structure: structure,
  selectedResidues: selection,
  highlights: annotations,
  onSelectionChanged: (next) {
    setState(() => selection = next);
  },
  onResidueHover: (hit) {
    setState(() => hoveredResidue = hit);
  },
)
```

The sequence viewer reads and updates the same application-owned `selection`. The parent rebuilds the widgets when that state changes. Replace sets and maps rather than modifying previously supplied collections in place.

| Property | Behavior |
| --- | --- |
| `selectedResidues: null` (default) | The viewer owns selection internally. |
| `selectedResidues: <ResidueKey>{}` | The application controls selection; nothing is selected. |
| `selectedResidues: keys` | The application controls the selected residues. |
| `highlights: Map<ResidueKey, Color>` | Independent, application-owned color annotations. Defaults to empty. |

In controlled mode, user interactions propose a new immutable set through `onSelectionChanged`. The displayed selection changes when the application supplies that set. External property updates do not emit interaction callbacks. In standalone mode, selection updates immediately and the same callback can observe it. `onResidueTap` reports individual clicks, including null for background.

An ordinary click replaces selection. Shift/control/meta-click toggles a residue within the selection. Clicking the background clears selection. Releasing external control retains the last visible selection. Replacing the structure clears internal selection; externally supplied keys are intersected with the new structure.

Highlights do not change selection. Colors resolve in this order: hover, selection, annotation, secondary-structure color. Changing selection, annotations, or style reuses geometry and preserves camera position.

### Residue identity

```dart
final key = ResidueKey(chain.id, residue.id);
```

`chain.id` is mmCIF `label_asym_id`, the unique chain instance identifier. `chain.authChainId` is the author-facing display name and may be shared by chains. `residue.id` contains `auth_seq_id` and the insertion code. Keys are scoped to one structure. The callback's `ResidueHit` contains the key, chain, and residue.

Map sequence positions to parsed residues explicitly: missing coordinates, insertion codes, and author numbering mean a sequence index is not a residue ID. Unknown keys are ignored by the viewer. Residues without a drawable Cα backbone segment remain available in the model but cannot be picked in the cartoon.

## Camera and styling

```dart
final controller = ProteinViewerController();

ProteinViewer(
  structure: structure,
  controller: controller,
  style: const CartoonStyle(
    helixColor: Colors.red,
    sheetColor: Colors.amber,
    loopColor: Colors.grey,
    outlineColor: Colors.black,
    outlineThickness: 0.05,
    pencilTexture: false,
  ),
)

controller.resetCamera();
controller.focusResidue(key);
controller.focusChain(chain.id);
```

Create a controller once in the owning widget's state and dispose it with that state. One controller may attach to one viewer at a time. Camera commands return false while the renderer is unavailable or when the requested target is missing.

Drag to rotate, scroll/pinch to zoom, and shift-drag or use two fingers to pan. Customize loading, initialization errors, and empty data using `loadingBuilder`, `errorBuilder`, and `emptyBuilder`. Parse/loading errors belong to the application; the viewer's error builder handles renderer initialization failures.

## Scope and limitations

- One mmCIF entry at a time, including multiple amino acid chains.
- Cartoon rendering only. No legacy `.pdb` input, ligands, waters, or nucleic acids.
- First data block and first encountered coordinate model; alternate atoms are resolved by occupancy, with file order breaking ties.
- Header secondary structure is used when usable ranges exist; otherwise a Cα-based P-SEA fallback is used. This fallback identifies alpha helices and does not reproduce every depositor annotation. It is based on Labesse et al.'s original method: [Labesse et al. (1997), *Bioinformatics* 13(3), 291–295](https://doi.org/10.1093/bioinformatics/13.3.291).
- Models snapshot their input lists and coordinates. `Atom.position` returns a copy in ångströms.
- Parsing uses a worker isolate on native platforms. Web parsing and mesh construction execute on the UI thread; large structures can cause pauses.
- Picking uses approximate per-residue boxes. It is not atom-level hit testing.
- Secondary-structure header ranges currently prefer label sequence numbers,
  while residue identities use author numbering. Entries where these differ
  need additional validation; header assignments may be inaccurate.

See [architecture](architecture.md) for implementation boundaries and
[platform setup](platforms.md) for consumer configuration.

`Protein` and `AminoAcidSequence` remain sequence-oriented models. A parsed
`MolecularStructure` holds resolved coordinates independently: one structure can
contain multiple chains and omit sequence positions. Applications should keep an
explicit mapping from their sequence positions to `ResidueKey` values; author
numbering and insertion codes are not sequence indexes. The viewer does not
silently merge coordinate data into an existing `Protein`.

## Example and development

The [example](../../example/protein_viewer/lib/main.dart) demonstrates linked sequence selection, standalone selection, annotations, outlines, pencil texture, and camera reset.

```sh
fvm install
fvm flutter pub get
cd example/protein_viewer
fvm flutter pub get
```

The example intentionally omits generated platform runners. To run it, generate
the desired runner locally and apply the settings in [platform setup](platforms.md).

FVM reads the parent `.fvmrc` from the example directory. It pins Flutter revision `cf97bfbcb9f508a35cfdc451f4c2d19e30ad6b7c` (3.48.0-1.0.pre-204). Installing it can create a separate FVM cache entry even if `master` already points at that revision. Scene is pinned to 0.20.0.

From the package root:

```sh
fvm dart format lib/protein_viewer.dart lib/src/structure test/structure example/protein_viewer/lib
fvm flutter analyze
fvm flutter test
```

Formatting follows BioFlutter's default Dart formatter settings. CI runs analysis
and tests on Linux, macOS, and Windows. Visual verification is performed manually.
