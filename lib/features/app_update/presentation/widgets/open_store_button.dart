import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/extensions/context_x.dart';
import '../../../../core/utils/app_logger.dart';

class OpenStoreButton extends StatelessWidget {
  const OpenStoreButton({
    required this.storeUrl,
    this.compact = false,
    super.key,
  });

  final Uri? storeUrl;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final url = storeUrl;
    final label = Text(context.l10n.updateNow);
    final onPressed = url == null ? null : () => unawaited(_open(url));
    return compact
        ? TextButton(onPressed: onPressed, child: label)
        : FilledButton(onPressed: onPressed, child: label);
  }

  static Future<void> _open(Uri url) async {
    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) AppLogger.warning('Could not open store url $url');
  }
}
