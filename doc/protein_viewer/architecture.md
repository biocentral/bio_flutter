# Architecture

The public library exports the viewer, style, controller, parser, and molecular
model. Flutter Scene objects remain under `lib/src` and are not public API.

| Module | Responsibility |
| --- | --- |
| `api/` | Consumer widget, configuration, camera commands, asynchronous parser |
| `model/` | Immutable structural data and residue identity |
| `cif/`, `mmcif/` | CIF syntax and protein interpretation |
| `ss/` | Geometric secondary-structure assignment |
| `interaction/` | Controlled/uncontrolled selection transitions |
| `scene/` | Geometry, camera, hit proxies, GPU updates |

`ProteinViewer` owns the camera and the active `ViewerScene`. Each structure
replacement starts a new initialization generation. Late results from an older
generation are discarded; unmounting also invalidates pending work. Controller
attachment is scoped to the widget lifetime.

`ViewerScene` is an internal GPU boundary. Widget tests substitute a fake scene
to verify input handling, controlled state, callbacks, replacement, disposal,
and camera preservation. Geometry and parser tests exercise the real algorithms.
Visual verification is platform-dependent; current results are tracked in [platform setup](platforms.md).

`SelectionState` snapshots controlled inputs and emits immutable proposals.
The renderer has no authority to change application selection. Color precedence
is hover, selection, annotations, then secondary structure. Colors are compared
per run so unchanged buffers are not uploaded. A style change does not rebuild
the ribbon mesh.

Scene 0.20 has no public scene/mesh disposal method. Removing `SceneView` ends its
widget lifecycle; the viewer releases its references and indexes. Scene's GPU
objects remain managed by the dependency. The pencil texture is cached per isolate.

## Maintenance conventions

- Follow BioFlutter's default Dart formatter settings.
- Document public behavior, units, ownership, defaults, and failure modes with
  concise `///` comments. Use `[identifier]` links only for resolvable symbols.
- Use `//` for non-obvious mathematical or implementation constraints. Keep
  scientific references and invariants; omit narration of straightforward code.
- Put development history in Git rather than source comments. Longer design
  explanations belong here.
- Keep selection and style tests independent of the GPU. Add regression tests
  for changes to parsing, identity, geometry, or lifecycle behavior.

These conventions follow [Effective Dart documentation guidance](https://dart.dev/effective-dart/documentation).
