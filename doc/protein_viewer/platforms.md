# Platform setup

The example includes configuration for Linux, macOS, Windows, and web. Native
Flutter GPU configuration belongs to the consuming application's runner; a Dart
package cannot change it automatically.

Use the revision in `.fvmrc` for reproducible development. The runner APIs below
were checked against that SDK. The package's pre-release Flutter/Dart constraints
are intentional; broad stable-SDK compatibility has not been validated.

## Linux

In `linux/runner/my_application.cc`, after creating the Dart project:

```cpp
g_autoptr(FlDartProject) project = fl_dart_project_new();
fl_dart_project_set_enable_impeller(project, TRUE);
fl_dart_project_set_enable_flutter_gpu(project, TRUE);
```

```sh
fvm flutter run -d linux
fvm flutter build linux
```

## Windows

In `windows/runner/main.cpp`, after creating the Dart project:

```cpp
flutter::DartProject project(L"data");
project.set_enable_flutter_gpu(true);
project.set_impeller_switch(flutter::ImpellerSwitch::Enabled);
```

```sh
fvm flutter run -d windows
fvm flutter build windows
```

## macOS

Add Boolean values to the `<dict>` in `macos/Runner/Info.plist`:

```xml
<key>FLTEnableFlutterGPU</key>
<true/>
<key>FLTEnableImpeller</key>
<true/>
```

```sh
fvm flutter run -d macos
fvm flutter build macos
```

## Web

Scene 0.20 uses its WebGL2 backend. No native GPU flags or runner edits are
needed. Serve the build through a web server, not a `file://` URL.

```sh
fvm flutter run -d chrome
fvm flutter build web
```

WebAssembly compilation was checked by Flutter's build dry run; browser runtime
verification so far covers the default JavaScript build only.

## Verification status

| Platform | Build | Visual verification |
| --- | --- | --- |
| Linux | Release build passed | Confirmed by the project owner |
| Chrome/web | Release build passed | Confirmed by the project owner |
| macOS | Configuration added; native build pending | Pending |
| Windows | Configuration added; native build pending | Pending |

The CI workflow provides native build jobs on all three desktop operating
systems. Adding those jobs does not imply they have already passed.

Sources: [Scene 0.20 requirements](https://pub.dev/packages/flutter_scene/versions/0.20.0),
[Flutter GPU](https://docs.flutter.dev/perf/impeller#flutter-gpu), and the
Linux/Windows runner headers at the pinned Flutter SDK revision.
