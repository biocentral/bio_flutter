## 0.0.5

### Maintenance
* Multiple lines for sequences in protein fasta files are now allowed and concatenated
* File names are now automatically added to loaded entities (column name `ExtractedDataset`)
* Updating dependencies

## 0.0.4

### Maintenance
* Fixing image path in README

## 0.0.3

### Maintenance
* Fixing image path in README
* Renaming umap example to example.dart
* Fixing package description length

## 0.0.2

### Maintenance
* Adding BSD License

## 0.0.1

Initial release

### Features
**Widgets**:
* UMAP Visualizer

**Biological Data Classes**:
* Protein
* Sequence: AminoAcidSequence, NucleotideSequence
* Protein-Protein Interaction
* Taxonomy

**Protein Representation and Data Analysis**:
* Embedding: PerSequence, PerResidue
* UMAP

**File handling**:
* Protein: fasta
* ProteinProteinInteraction: fasta
* Embedding: json
* UMAPData: csv
* CustomAttributes: csv
