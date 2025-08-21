import 'package:flutter/material.dart';

class ControlsBar extends StatelessWidget {
  final bool isDetecting;
  final VoidCallback onToggleDetection;
  final VoidCallback onSwitchCamera;
  final int backCamerasCount;
  final int selectedCameraIndex;

  const ControlsBar({
    super.key,
    required this.isDetecting,
    required this.onToggleDetection,
    required this.onSwitchCamera,
    required this.backCamerasCount,
    required this.selectedCameraIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      height: 100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            icon: Icon(
              isDetecting ? Icons.stop : Icons.play_arrow,
              color: Colors.white,
            ),
            onPressed: onToggleDetection,
          ),
          if (backCamerasCount > 1)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.switch_camera, color: Colors.white),
                  onPressed: onSwitchCamera,
                ),
                Text(
                  'Cam: ${selectedCameraIndex + 1}',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
