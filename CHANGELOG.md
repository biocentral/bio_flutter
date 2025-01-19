## 0.0.9
* (BREAKING) Renaming "UMAP" to more general "Projection" term
This includes the data class, the visualizer, file handling and test cases
* Updating dependencies

## 0.0.8
* Adding testing strategy
* Making toMap more generic for bio entities
* Adding toString function for sequence
* Adding preliminary OneHotEncodingEmbedder

## 0.0.7
* Adding `TypeNameMixin` for all biological entities to be able to display the class name at runtime, 
even for optimized types in flutter web renderer

## 0.0.6

### Features
* Adding `Cell` and `CellMeasurements` data classes
* Adding `CellFCSParser` stub

### Maintenance
* Changing bio_file_handler structure to be able to handle both string and binary file types (breaking changes for
string converting and parsing)

## 0.0.5

### Features
* Adding `EmbeddingsCombiner`
Is able to combine two embeddings via a combining function, currently multiply elementwise and concatenation. 
Enables `ProteinProteinInteraction` to provide the getEmbeddings interface.
* Adding draft classes for `AminoAcid` and `Atom` to represent protein structure (work in progress)

### Maintenance
* Multiple lines for sequences in protein fasta files are now allowed and concatenated
* File names are now automatically added to loaded entities (column name `ExtractedDataset`)
* Renaming `BiologicalEntity` to `BioEntity`
* Making `nullableMerge` applicable for non-comparable types
* Adding toMap() and getEmbeddings() to `BioEntity` interface
* Introducing functional error handling via `fpdart`, will be more widely adapted in future releases
* Moving package to `biocentral` organization
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
