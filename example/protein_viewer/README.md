# Example

Run `fvm flutter pub get` here. The parent `.fvmrc` selects the SDK. Generated
platform runners are intentionally omitted; create the desired runner locally
before launching the example.

The sequence chips and structure viewer share selection when **Link sequence
selection** is enabled. Turn it off to use the viewer's internal selection.
Annotations are independent purple highlights; selection and hover take visual
precedence over them.

See [platform setup](../../doc/protein_viewer/platforms.md) for the required native
runner configuration. The example uses the public package entry point and has no
direct Scene dependency.
