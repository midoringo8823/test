// Copyright 2016 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../artifacts.dart';
import '../base/process.dart';
import '../globals.dart';
import '../runner/flutter_command_runner.dart';

Uri _xcodeProjectUri(String revision) {
  String uriString = 'https://storage.googleapis.com/flutter_infra/flutter/$revision/ios/FlutterXcode.zip';
  return Uri.parse(uriString);
}

Future<List<int>> _fetchXcodeArchive() async {
  printStatus('Fetching the Xcode project archive from the cloud...');

  HttpClient client = new HttpClient();

  Uri xcodeProjectUri = _xcodeProjectUri(ArtifactStore.engineRevision);
  printStatus('Downloading $xcodeProjectUri...');
  HttpClientRequest request = await client.getUrl(xcodeProjectUri);
  HttpClientResponse response = await request.close();

  if (response.statusCode != 200)
    throw new Exception(response.reasonPhrase);

  BytesBuilder bytesBuilder = new BytesBuilder(copy: false);
  await for (List<int> chunk in response)
    bytesBuilder.add(chunk);

  return bytesBuilder.takeBytes();
}

Future<bool> _inflateXcodeArchive(String directory, List<int> archiveBytes) async {
  printStatus('Unzipping Xcode project to local directory...');

  // We cannot use ArchiveFile because this archive contains files that are exectuable
  // and there is currently no provision to modify file permissions during
  // or after creation. See https://github.com/dart-lang/sdk/issues/15078.
  // So we depend on the platform to unzip the archive for us.

  Directory tempDir = await Directory.systemTemp.create();
  File tempFile = new File(path.join(tempDir.path, 'FlutterXcode.zip'))..createSync();
  tempFile.writeAsBytesSync(archiveBytes);

  try {
    // Remove the old generated project if one is present
    runCheckedSync(['/bin/rm', '-rf', directory]);
    // Create the directory so unzip can write to it
    runCheckedSync(['/bin/mkdir', '-p', directory]);
    // Unzip the Xcode project into the new empty directory
    runCheckedSync(['/usr/bin/unzip', tempFile.path, '-d', directory]);
  } catch (error) {
    return false;
  }

  // Cleanup the temp directory after unzipping
  runSync(['/bin/rm', '-rf', tempDir.path]);

  Directory flutterDir = new Directory(path.join(directory, 'Flutter'));
  bool flutterDirExists = await flutterDir.exists();
  if (!flutterDirExists)
    return false;

  // Move contents of the Flutter directory one level up
  // There is no dart:io API to do this. See https://github.com/dart-lang/sdk/issues/8148

  for (FileSystemEntity file in flutterDir.listSync()) {
    try {
      runCheckedSync(['/bin/mv', file.path, directory]);
    } catch (error) {
      return false;
    }
  }

  runSync(['/bin/rm', '-rf', flutterDir.path]);

  return true;
}

void updateXcodeLocalProperties(String projectPath) {
  StringBuffer localsBuffer = new StringBuffer();

  localsBuffer.writeln('// This is a generated file; do not edit or check into version control.');

  String flutterRoot = path.normalize(Platform.environment[kFlutterRootEnvironmentVariableName]);
  localsBuffer.writeln('FLUTTER_ROOT=$flutterRoot');

  // This holds because requiresProjectRoot is true for this command
  String applicationRoot = path.normalize(Directory.current.path);
  localsBuffer.writeln('FLUTTER_APPLICATION_PATH=$applicationRoot');

  String dartSDKPath = path.normalize(path.join(Platform.resolvedExecutable, '..', '..'));
  localsBuffer.writeln('DART_SDK_PATH=$dartSDKPath');

  File localsFile = new File(path.join(projectPath, 'ios', '.generated', 'Local.xcconfig'));
  localsFile.createSync(recursive: true);
  localsFile.writeAsStringSync(localsBuffer.toString());
}

bool xcodeProjectRequiresUpdate() {
  File revisionFile = new File(path.join(Directory.current.path, 'ios', '.generated', 'REVISION'));

  // If the revision stamp does not exist, the Xcode project definitely requires
  // an update
  if (!revisionFile.existsSync()) {
    printTrace("A revision stamp does not exist. The Xcode project has never been initialized.");
    return true;
  }

  if (revisionFile.readAsStringSync() != ArtifactStore.engineRevision) {
    printTrace("The revision stamp and the Flutter engine revision differ. Project needs to be updated.");
    return true;
  }

  printTrace("Xcode project is up to date.");
  return false;
}

Future<int> setupXcodeProjectHarness(String flutterProjectPath) async {
  // Step 1: Fetch the archive from the cloud
  String iosFilesPath = path.join(flutterProjectPath, 'ios');
  String xcodeprojPath = path.join(iosFilesPath, '.generated');
  List<int> archiveBytes = await _fetchXcodeArchive();

  if (archiveBytes.isEmpty) {
    printError('Error: No archive bytes received.');
    return 1;
  }

  // Step 2: Inflate the archive into the user project directory
  bool result = await _inflateXcodeArchive(xcodeprojPath, archiveBytes);
  if (!result) {
    printError('Could not inflate the Xcode project archive.');
    return 1;
  }

  // Step 3: Populate the Local.xcconfig with project specific paths
  updateXcodeLocalProperties(flutterProjectPath);

  // Step 4: Write the REVISION file
  File revisionFile = new File(path.join(xcodeprojPath, 'REVISION'));
  revisionFile.createSync();
  revisionFile.writeAsStringSync(ArtifactStore.engineRevision);

  // Step 5: Tell the user the location of the generated project.
  printStatus('Xcode project created in $iosFilesPath/.');

  return 0;
}
