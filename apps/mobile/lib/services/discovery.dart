import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:howl_core/howl_core.dart';
import 'package:howl_net/howl_net.dart';
import 'package:nsd/nsd.dart' as nsd;

/// A room found on the local network.
class FoundRoom {
  FoundRoom({required this.name, required this.host, required this.port, this.info});

  final String name;
  final String host;
  final int port;
  final Map<String, dynamic>? info;

  int get players => info?['players'] as int? ?? 0;
  bool get inGame => info?['inGame'] == true;
  bool get locked => info?['locked'] == true;
  bool get hasPassword => info?['hasPassword'] == true;
  String get key => '$host:$port';
}

/// Announces a hosted room with Bonjour/NSD so phones on the same Wi-Fi
/// see it without typing an address.
class RoomAdvertiser {
  nsd.Registration? _reg;

  Future<void> start({required String roomName, required int port, required List<String> ips}) async {
    try {
      _reg = await nsd.register(nsd.Service(
        name: roomName,
        type: Net.serviceType,
        port: port,
        txt: {
          if (ips.isNotEmpty) 'ip': Uint8List.fromList(utf8.encode(ips.first)),
        },
      ));
    } catch (e) {
      debugPrint('NSD register failed: $e');
    }
  }

  Future<void> stop() async {
    final r = _reg;
    _reg = null;
    if (r != null) {
      try {
        await nsd.unregister(r);
      } catch (_) {}
    }
  }
}

/// Finds rooms on the local network and keeps the list fresh.
class RoomScanner extends ChangeNotifier {
  nsd.Discovery? _discovery;
  final Map<String, FoundRoom> _rooms = {};
  Timer? _refresh;

  List<FoundRoom> get rooms => _rooms.values.toList()..sort((a, b) => a.name.compareTo(b.name));

  Future<void> start() async {
    try {
      _discovery = await nsd.startDiscovery(Net.serviceType, ipLookupType: nsd.IpLookupType.v4);
      _discovery!.addServiceListener((service, status) {
        if (status == nsd.ServiceStatus.found) {
          _found(service);
        } else {
          _rooms.removeWhere((_, r) => r.name == service.name);
          notifyListeners();
        }
      });
    } catch (e) {
      debugPrint('NSD discovery failed: $e');
    }
    // Player counts change; refresh them every few seconds.
    _refresh = Timer.periodic(const Duration(seconds: 4), (_) => _refreshInfo());
  }

  Future<void> _found(nsd.Service s) async {
    final port = s.port;
    if (port == null) return;
    final candidates = <String>[
      ...?s.addresses?.where((a) => a.type == InternetAddressType.IPv4).map((a) => a.address),
      if (s.txt?['ip'] != null) utf8.decode(s.txt!['ip']!),
      if (s.host != null) s.host!,
    ];
    for (final host in candidates) {
      final info = await HowlClient.probe(host, port);
      if (info != null) {
        final room = FoundRoom(name: info['name'] as String? ?? s.name ?? host, host: host, port: port, info: info);
        _rooms[room.key] = room;
        notifyListeners();
        return;
      }
    }
  }

  Future<void> _refreshInfo() async {
    for (final r in _rooms.values.toList()) {
      final info = await HowlClient.probe(r.host, r.port, timeout: const Duration(seconds: 2));
      if (info == null) {
        _rooms.remove(r.key);
      } else {
        _rooms[r.key] = FoundRoom(name: r.name, host: r.host, port: r.port, info: info);
      }
    }
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    _refresh?.cancel();
    final d = _discovery;
    _discovery = null;
    if (d != null) {
      try {
        await nsd.stopDiscovery(d);
      } catch (_) {}
    }
    super.dispose();
  }
}
