// Copyright 2023 Jason C.H

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at

//     http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:espota/espota.dart';

class FlashCommand extends Command<void> {
  @override
  final String name = 'flash';

  @override
  final String description = 'Flash ESP chip via OTA.';

  late final String? ip;
  late final String? fwPath;

  FlashCommand() {
    argParser
      ..addOption(
        'ip',
        help: 'The IP address of ESP chip.',
        defaultsTo: '192.168.4.1',
        callback: (s) => ip = s,
      )
      ..addOption(
        'firmware',
        abbr: 'f',
        help: 'The path of firmware.',
        callback: (s) => fwPath = s,
      );
  }

  @override
  Future<void> run() async {
    if (ip == null || fwPath == null) {
      printUsage();
      return;
    }

    final fw = await File(fwPath!).readAsBytes();

    try {
      await for (final progress in await upgrade(InternetAddress(ip!), fw)) {
        print('> ${progress * 100}%');
      }
    } catch (e) {
      print('Failed: $e');
    }
  }
}
