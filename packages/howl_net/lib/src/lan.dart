import 'dart:io';

/// Local IPv4 addresses players can reach this device on, best first.
Future<List<String>> localIpv4Addresses() async {
  final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
  final out = <String>[];
  for (final i in interfaces) {
    for (final a in i.addresses) {
      if (!a.isLoopback && !a.isLinkLocal) out.add(a.address);
    }
  }
  int rank(String ip) {
    if (ip.startsWith('192.168.')) return 0; // home Wi-Fi and phone hotspots
    if (ip.startsWith('10.')) return 1;
    if (ip.startsWith('172.')) return 2;
    return 3;
  }

  out.sort((a, b) => rank(a) - rank(b));
  return out;
}
