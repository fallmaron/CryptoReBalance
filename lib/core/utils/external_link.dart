import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in an external browser, then Chrome Custom Tabs as fallback.
Future<bool> openExternalLink(String url) async {
  final uri = Uri.parse(url);
  const modes = [
    LaunchMode.externalApplication,
    LaunchMode.inAppBrowserView,
    LaunchMode.platformDefault,
  ];
  for (final mode in modes) {
    try {
      if (await launchUrl(uri, mode: mode)) {
        return true;
      }
    } catch (_) {
      continue;
    }
  }
  return false;
}
