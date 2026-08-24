import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/design/fp_colors.dart';
import '../../core/design/fp_tokens.dart';
import '../../core/design/fp_typography.dart';
import '../../shared/widgets/fp_metric.dart';
import '../../shared/widgets/fp_screen.dart';

/// Lets the user position the photo inside the circular frame before it is
/// saved. Cropping happens in-app, so no extra native dependency is needed and
/// the photo never leaves the device.
class AvatarFramer extends StatefulWidget {
  const AvatarFramer({required this.file, super.key});

  final File file;

  static const outputSize = 512;

  @override
  State<AvatarFramer> createState() => _AvatarFramerState();
}

class _AvatarFramerState extends State<AvatarFramer> {
  final _boundary = GlobalKey();
  final _transform = TransformationController();
  bool _saving = false;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final object =
          _boundary.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (object == null) throw StateError('Frame is not ready');

      final frameWidth = object.size.width;
      final image = await object.toImage(
        pixelRatio: AvatarFramer.outputSize / frameWidth,
      );
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (data == null) throw StateError('Could not encode the image');

      if (!mounted) return;
      Navigator.of(context).pop<Uint8List>(data.buffer.asUint8List());
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('That photo could not be processed. Try another one.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FpScreen(
      title: 'Position your photo',
      subtitle: 'Pinch to zoom, drag to move',
      bottomBar: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: FpSpace.xs),
          Expanded(
            child: FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Use photo'),
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          const Spacer(),
          Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final side = constraints.maxWidth.clamp(200.0, 320.0);
                return ClipOval(
                  child: RepaintBoundary(
                    key: _boundary,
                    child: Container(
                      width: side,
                      height: side,
                      color: FpColors.surfaceAlt,
                      child: InteractiveViewer(
                        transformationController: _transform,
                        minScale: 1,
                        maxScale: 5,
                        clipBehavior: Clip.hardEdge,
                        child: Image.file(
                          widget.file,
                          fit: BoxFit.cover,
                          width: side,
                          height: side,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: FpColors.graphiteSoft,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: FpSpace.md),
          Text(
            'Saved at ${AvatarFramer.outputSize}×${AvatarFramer.outputSize} px '
            'in the app folder on this device.',
            style: FpTypography.caption,
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          const FpNotice(
            message:
                'Your photo stays on this device. Featherpeak Fury has no '
                'account system and no server to upload it to.',
            icon: Icons.lock_outline_rounded,
          ),
          const SizedBox(height: FpSpace.md),
        ],
      ),
    );
  }
}
