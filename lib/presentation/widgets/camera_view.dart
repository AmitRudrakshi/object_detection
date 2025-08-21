import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CameraView extends StatefulWidget {
  final CameraController? cameraController;
  final Function(ScaleStartDetails) onScaleStart;
  final Function(ScaleUpdateDetails) onScaleUpdate;
  final Function(TapUpDetails) onTapUp;
  final double currentZoomLevel;
  final double minZoomLevel;
  final double maxZoomLevel;
  final double currentExposureOffset;
  final double minExposureOffset;
  final double maxExposureOffset;
  final Function(double) onExposureChanged;
  final Offset? focusPoint;

  const CameraView({
    super.key,
    required this.cameraController,
    required this.onScaleStart,
    required this.onScaleUpdate,
    required this.onTapUp,
    required this.currentZoomLevel,
    required this.minZoomLevel,
    required this.maxZoomLevel,
    required this.currentExposureOffset,
    required this.minExposureOffset,
    required this.maxExposureOffset,
    required this.onExposureChanged,
    this.focusPoint,
  });

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  @override
  Widget build(BuildContext context) {
    if (widget.cameraController == null ||
        !widget.cameraController!.value.isInitialized) {
      return const Center(child: Text('Initializing Camera...'));
    }

    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return AspectRatio(
                aspectRatio: widget.cameraController!.value.aspectRatio,
                child: GestureDetector(
                  onScaleStart: widget.onScaleStart,
                  onScaleUpdate: widget.onScaleUpdate,
                  onTapUp: (details) => widget.onTapUp(details),
                  child: CameraPreview(widget.cameraController!),
                ),
              );
            },
          ),
        ),
        _buildExposureSlider(),
        if (widget.focusPoint != null) _buildFocusIndicator(),
      ],
    );
  }

  Widget _buildExposureSlider() {
    return Positioned(
      right: 5,
      top: MediaQuery.of(context).size.height / 4,
      bottom: MediaQuery.of(context).size.height / 4,
      child: Column(
        children: [
          const Icon(Icons.exposure, color: Colors.white),
          Expanded(
            child: RotatedBox(
              quarterTurns: 1,
              child: Slider(
                value: widget.currentExposureOffset,
                min: widget.minExposureOffset,
                max: widget.maxExposureOffset,
                onChanged: widget.onExposureChanged,
                activeColor: Colors.white,
                inactiveColor: Colors.white30,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFocusIndicator() {
    return Positioned(
      left: widget.focusPoint!.dx - 40,
      top: widget.focusPoint!.dy - 40,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.yellow, width: 2),
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
