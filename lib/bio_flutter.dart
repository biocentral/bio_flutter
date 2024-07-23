/// Widgets, file handlers and utilities for
/// cross-platform representation and visualization of biological data in flutter.
library bio_flutter;

export 'src/attributes/custom_attributes.dart';

export 'src/files/bio_file_handler.dart';
export 'src/files/umap_csv_handler.dart';
export 'src/files/embedding_json_handler.dart';
export 'src/files/protein_fasta_handler.dart';
export 'src/files/interaction_fasta_handler.dart';
export 'src/files/custom_attributes_csv_handler.dart';

export 'src/interaction/protein_protein_interaction.dart';

export 'src/interfaces/bio_entity.dart';

export 'src/protein/embedding.dart';
export 'src/protein/protein.dart';
export 'src/protein/sequence.dart';

export 'src/taxonomy/taxonomy.dart';

export 'src/visualization/umap.dart';
export 'src/widgets/umap_visualizer.dart';

export 'src/util/type_util.dart';
export 'src/util/web_util.dart';