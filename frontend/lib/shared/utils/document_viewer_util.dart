import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Opens and views any document or image attachment across mobile, web, and desktop.
///
/// - For Images (.png, .jpg, .jpeg, .webp, .gif, .bmp): Opens an interactive in-app viewer with pinch-to-zoom & pan.
/// - For PDFs and other files: Safely launches via the system default application / Google Drive.
void viewDocumentOrImage(
  BuildContext context,
  String? rawUrl, {
  String? title,
}) async {
  if (rawUrl == null || rawUrl.trim().isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No document attachment URL available.')),
      );
    }
    return;
  }

  // Normalize relative URLs to absolute backend URLs
  String url = rawUrl.trim();
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    final base = AppConstants.baseUrl.endsWith('/')
        ? AppConstants.baseUrl.substring(0, AppConstants.baseUrl.length - 1)
        : AppConstants.baseUrl;
    final path = url.startsWith('/') ? url : '/$url';
    url = '$base$path';
  }

  final cleanPath = url.toLowerCase().split('?').first;
  final bool isImage = cleanPath.endsWith('.png') ||
      cleanPath.endsWith('.jpg') ||
      cleanPath.endsWith('.jpeg') ||
      cleanPath.endsWith('.webp') ||
      cleanPath.endsWith('.gif') ||
      cleanPath.endsWith('.bmp');

  if (isImage) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: ctx.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title ?? 'Attachment Preview',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ctx.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Iconsax.document_download, size: 20),
                          onPressed: () async {
                            final uri = Uri.parse(url);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            }
                          },
                          tooltip: 'Open in external browser / Download',
                          color: AppColors.primary,
                        ),
                        IconButton(
                          icon: const Icon(Iconsax.close_circle, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      color: ctx.card,
                      alignment: Alignment.center,
                      child: InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Center(
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                    : null,
                                color: AppColors.primary,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Iconsax.image, size: 40, color: AppColors.textSecondary),
                              const SizedBox(height: 8),
                              const Text('Failed to load image', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final uri = Uri.parse(url);
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                                icon: const Icon(Iconsax.export_1, size: 14),
                                label: const Text('Open External', style: TextStyle(fontSize: 12)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  } else {
    final uri = Uri.parse(url);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open document: $e')),
          );
        }
      }
    }
  }
}
