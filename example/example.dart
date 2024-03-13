import 'package:bio_flutter/bio_flutter.dart';
import 'package:flutter/material.dart';

List<Protein> sampleData() {
  Taxonomy human = const Taxonomy(id: 9606, name: "Homo sapiens", family: "Hominidae");
  Taxonomy lyssaVirus = const Taxonomy(id: 11286, name: "Lyssavirus", family: "Rhabdoviridae");
  return [
    Protein("Seq1", sequence: Sequence.buildVerifiedFromString("SEQWENCE")!, taxonomy: human),
    Protein("Seq2", sequence: Sequence.buildVerifiedFromString("PRTEIN")!, taxonomy: lyssaVirus),
    Protein("Seq3", sequence: Sequence.buildVerifiedFromString("SEQVENCEPRTEI")!, taxonomy: human),
    Protein("Seq4", sequence: Sequence.buildVerifiedFromString("SEQ")!, taxonomy: lyssaVirus),
    Protein("Seq5", sequence: Sequence.buildVerifiedFromString("PRTEINSEQWENCE")!, taxonomy: lyssaVirus)
  ];
}

void main() {
  final List<Protein> proteinExampleData = sampleData();
  runApp(BioFlutterUMAPExample(
    proteinExampleData: proteinExampleData,
  ));
}

class BioFlutterUMAPExample extends StatelessWidget {
  final List<Protein> proteinExampleData;

  const BioFlutterUMAPExample({super.key, required this.proteinExampleData});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'bio_flutter UMAP Example',
      theme: ThemeData(
        useMaterial3: false,
        primaryColor: const Color(0xFF321F5D),
        fontFamily: 'Georgia',
      ),
      home: UMAPViewerPage(proteinExampleData: proteinExampleData),
    );
  }
}

class UMAPViewerPage extends StatelessWidget {
  final List<Protein> proteinExampleData;

  const UMAPViewerPage({super.key, required this.proteinExampleData});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: UmapVisualizer(
      umapData: UMAPData.random(proteinExampleData.length),
      pointData: proteinExampleData.map((protein) => protein.toMap()).toList(),
      pointIdentifierKey: "id",
    ));
  }
}
