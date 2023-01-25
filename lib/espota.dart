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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

/// Upgrade ESP chip via OTA.
Future<Stream<double>> upgrade(
  InternetAddress address,
  List<int> firmware, {
  int port = 8266,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final fwLength = firmware.length;
  final fwMD5 = hex.encode(md5.convert(firmware).bytes);
  final controller = StreamController<double>();
  final tcpPort = Random().nextInt(50000) + 10000;

  ServerSocket? serverSocket;
  Socket? tcpSocket;
  RawDatagramSocket? udpSocket;
  Timer? timer;

  serverSocket = await ServerSocket.bind(InternetAddress.anyIPv4, tcpPort);

  Future<void> close() async {
    timer?.cancel();
    udpSocket?.close();
    await tcpSocket?.close();
    await serverSocket?.close();
    await controller.close();
  }

  Future<void> fail(Object error) async {
    if (!controller.isClosed) {
      controller.addError(error);
    }
    await close();
  }

  timer = Timer(timeout, () => fail(TimeoutException(null)));

  serverSocket.first.then<FutureOr<void>>(
    (s) {
      tcpSocket = s;
      var totalWritten = 0;
      s.listen(
        (event) async {
          final msg = utf8.decode(event);
          if (msg.contains('OK')) {
            await close();
            return;
          }
          final written = int.parse(msg);
          if (written < 100000) {
            // Try to prevent sticky packet.
            totalWritten += written;
          }
          controller.add(totalWritten / fwLength);
        },
        onError: fail,
      );
      s.add(firmware);
    },
    onError: fail,
  );

  udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);

  udpSocket
    ..firstWhere((e) => e == RawSocketEvent.read).then<FutureOr<void>>(
      (value) async {
        final dg = udpSocket?.receive();
        if (dg != null) {
          final msg = utf8.decode(dg.data);
          if (!msg.contains('OK')) {
            close();
          } else {
            udpSocket?.close();
            udpSocket = null;
          }
        }
      },
      onError: fail,
    )
    ..send(
      utf8.encode('0 $tcpPort $fwLength $fwMD5\n'),
      address,
      port,
    );

  return controller.stream;
}
