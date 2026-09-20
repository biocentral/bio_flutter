/// Embeddable cartoon rendering and mmCIF parsing for amino acid chains.
library;

export 'src/structure/api/cartoon_style.dart';
export 'src/structure/api/mmcif_parser.dart';
export 'src/structure/api/protein_viewer.dart';
export 'src/structure/api/protein_viewer_controller.dart'
    show ProteinViewerController;
export 'src/structure/model/atom.dart' show Atom;
export 'src/structure/model/chain.dart' show Chain;
export 'src/structure/model/molecular_structure.dart' show MolecularStructure;
export 'src/structure/model/residue.dart' show Residue, ResidueId;
export 'src/structure/model/residue_key.dart' show ResidueKey;
export 'src/structure/model/secondary_structure.dart'
    show SecondaryStructureType;
