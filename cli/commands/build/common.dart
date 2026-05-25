import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart';
import 'package:process_run/shell_run.dart';
import 'package:pubspec_parse/pubspec_parse.dart';

import '../../core/env.dart';

mixin BuildCommandCommonSteps on Command {
  final shell = Shell();
  Directory get cwd => Directory.current;

  Pubspec? _pubspec;

  Pubspec get pubspec {
    if (_pubspec != null) {
      return _pubspec!;
    }

    final pubspecFile = File(join(cwd.path, "pubspec.yaml"));
    _pubspec = Pubspec.parse(pubspecFile.readAsStringSync());

    return _pubspec!;
  }

  String get versionWithoutBuildNumber {
    return "${pubspec.version!.major}.${pubspec.version!.minor}.${pubspec.version!.patch}";
  }

  RegExp get versionVarRegExp =>
      RegExp(r"\%\{\{SPOTUBE_VERSION\}\}\%", multiLine: true);

  File get dotEnvFile => File(join(cwd.path, ".env"));

  Future<void> bootstrap() async {
    await dotEnvFile.create(recursive: true);

    var dotenvContent = CliEnv.dotenv;
    if (!dotenvContent.contains("LASTFM_API_KEY")) {
      dotenvContent += "\nLASTFM_API_KEY=dummy_lastfm_key";
    }
    if (!dotenvContent.contains("LASTFM_API_SECRET")) {
      dotenvContent += "\nLASTFM_API_SECRET=dummy_lastfm_secret";
    }
    if (!dotenvContent.contains("HIDE_DONATIONS")) {
      dotenvContent += "\nHIDE_DONATIONS=0";
    }
    if (!dotenvContent.contains("ENABLE_UPDATE_CHECK")) {
      dotenvContent += "\nENABLE_UPDATE_CHECK=1";
    }

    await dotEnvFile.writeAsString(
      "$dotenvContent\n"
      "RELEASE_CHANNEL=${CliEnv.channel.name}\n",
    );

    if (CliEnv.channel == BuildChannel.nightly) {
      final pubspecFile = File(join(cwd.path, "pubspec.yaml"));

      pubspecFile.writeAsStringSync(
        pubspecFile.readAsStringSync().replaceAll(
              "version: ${pubspec.version!.canonicalizedVersion}",
              "version: $versionWithoutBuildNumber+${CliEnv.ghRunNumber}",
            ),
      );

      _pubspec = null;
      pubspec;
    }

    await shell.run(
      """
      flutter pub get
      dart run build_runner build --delete-conflicting-outputs
      dart pub global activate fastforge
      """,
    );
  }

  String get architecture => parent?.argResults?.option("arch") as String;
}
