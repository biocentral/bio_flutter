<!--
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/guides/libraries/writing-package-pages).

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-library-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/developing-packages).
-->

Cross-platform representation and visualization of biological data in flutter.

## Features

**Widgets**:

* Protein structure viewer: interactive cartoon rendering of amino acid chains
  from mmCIF, with selection, residue color annotations, and camera controls.
  See the [viewer guide](doc/protein_viewer/README.md) and
  [platform setup](doc/protein_viewer/platforms.md).

The structure viewer requires the Flutter revision pinned in `.fvmrc`
(3.48.0-1.0.pre-204). This raises the SDK requirements for all consumers of
`bio_flutter`. Native applications must configure their runner as documented above.

* Projection Data Visualizer:

<img src="https://github.com/SebieF/bio_flutter/blob/v0.0.9/doc/projection_visualizer.gif?raw=true" 
alt="An animated image of the Projection Visualizer widget" height="398" width="816" title="Projection Visualizer"/>

**Biological Data Classes**:

* Protein
* Sequence: AminoAcidSequence, NucleotideSequence
* Protein-Protein Interaction
* Taxonomy

**Protein Representation and Data Analysis**:

* Embedding: PerSequence, PerResidue
* UMAP

**File handling**:

| Name                      | fasta | csv | json |
|---------------------------|:-----:|:---:|:----:|
| Protein                   |   ✅   |  ❌  |  ❌   | 
| ProteinProteinInteraction |   ✅   |  ❌  |  ❌   | 
| Embedding                 |   ❌   |  ❌  |  ✅   | 
| ProjectionData            |   ❌   |  ✅  |  ❌   | 
| CustomAttributes          |   ❌   |  ✅  |  ❌   |

## Usage

**Load and write a protein fasta file**:

```dart
import 'package:flutter_test/flutter_test.dart';

Future<List<Protein>> readFastaFileProtein(String pathToFile) async {
  BioFileHandlerContext<Protein>? handler = BioFileHandler<Protein>().create(pathToFile);
  Map<String, Protein> proteins = await handler.read();
  return proteins.values.toList();
}

Future<void> saveProteins(List<Protein> proteins, String pathToFile) async {
  // Saves the file on desktop/mobile, downloads on web
  BioFileHandlerContext<Protein>? handler = BioFileHandler<Protein>().create(pathToFile);
  await handler.write(proteins.asMap().map((_, value) => MapEntry(value.id, value)));
}
```

**Add custom attributes to your proteins**:

```dart
import 'package:flutter_test/flutter_test.dart';

Future<List<Protein>> addCustomAttributes(List<Protein> proteins, String pathToFile) async {
  BioFileHandlerContext<CustomAttributes>? handler = BioFileHandler<CustomAttributes>().create(pathToFile);
  Map<String, CustomAttributes> attributes = await handler.read();
  List<Protein> updatedProteins = [];
  for (Protein protein in proteins) {
    if (attributes.containsKey(protein.id)) {
      Protein updated = protein.updateFromCustomAttributes(attributes[protein.id]!);
      updatedProteins.add(updated);
    }
  }
  return updatedProteins;
}
```

**Create a UMAP Visualizer Widget with random coordinates**:

```dart
Widget createProjectionWidget(List<ProteinProteinInteraction> interactionData) {
  return ProjectionVisualizer(
      projectionData: ProjectionData.random(interactionData.length),
      pointIdentifierKey: "id",
      pointData: interactionData.map((interaction) => interaction.toMap()).toList()); // Also works with protein data
}
```

## Additional information

The correctness of the provided operations is the most important focus of this package in order to be useful for
scientists and practitioners in research and development. We are grateful for every reported bug and contribution to
the codebase on GitHub!

**Current Roadmap**:

* Increase test coverage
* Improve documentation
* Support more file formats for all data types
* Extend 3D protein visualization
