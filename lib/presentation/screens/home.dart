import 'dart:async';
import 'dart:developer';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/camera_view.dart';
import '../../utils/isolate_utils.dart';
import 'splash_screen.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({super.key, required this.cameras});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraController? _cameraController;
  Interpreter? _interpreter;
  List<String> _labels = [];
  List<dynamic>? _recognitions;
  bool _isDetecting = false;
  bool _isBusy = false;
  bool _modelLoaded = false;
  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _baseZoomLevel = 1.0;

  // New state variables for camera interactions
  double _minExposureOffset = 0.0;
  double _maxExposureOffset = 0.0;
  double _currentExposureOffset = 0.0;
  Offset? _focusPoint;
  Timer? _focusPointTimer;
  List<CameraDescription> _backCameras = [];
  int _selectedBackCameraIndex = 0;

  late Isolate _isolate;
  late ReceivePort _receivePort;
  late SendPort _sendPort;

  @override
  void initState() {
    super.initState();
    _loadModelAndLabels().then((_) {
      setState(() {
        _modelLoaded = true;
      });
      _initializeCamera();
    });
    _initIsolate();
  }

  Future<void> _loadModelAndLabels() async {
    log("initState: Loading model and labels");
    await _loadModel();
    await _loadLabels();
    _backCameras = widget.cameras
        .where((c) => c.lensDirection == CameraLensDirection.back)
        .toList();
    if (_backCameras.isEmpty) {
      _backCameras = widget.cameras;
    }
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/yolov2_tiny.tflite');
      log("Model loaded successfully");
    } catch (e) {
      log('Error loading model: $e');
    }
  }

  Future<void> _loadLabels() async {
    try {
      final String labelsContent = await rootBundle.loadString(
        'assets/labels.txt',
      );
      setState(() {
        _labels = labelsContent.split('\n');
      });
      log("Labels loaded successfully");
    } catch (e) {
      log('Error loading labels: $e');
    }
  }

  void _initIsolate() async {
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(runInference, _receivePort.sendPort);
    _receivePort.listen((dynamic data) {
      if (data is SendPort) {
        _sendPort = data;
      } else if (data is List<dynamic>) {
        if (mounted) {
          setState(() {
            _recognitions = data;
          });
        }
      }
    });
  }

  Future<void> _initializeCamera() async {
    log("Initializing camera...");
    if (_backCameras.isEmpty) {
      log("No back cameras available");
      return;
    }

    await _cameraController?.dispose();

    _cameraController = CameraController(
      _backCameras[_selectedBackCameraIndex],
      ResolutionPreset.high,
      enableAudio: false,
    );

    try {
      await _cameraController!.initialize();
      if (!mounted) return;

      log("Camera initialized");

      _minZoomLevel = await _cameraController!.getMinZoomLevel();
      _maxZoomLevel = await _cameraController!.getMaxZoomLevel();
      _minExposureOffset = await _cameraController!.getMinExposureOffset();
      _maxExposureOffset = await _cameraController!.getMaxExposureOffset();

      _currentZoomLevel = _minZoomLevel;
      _currentExposureOffset = 0.0;

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      log("Error initializing camera: $e");
    }
  }

  void _toggleDetection() {
    setState(() {
      _isDetecting = !_isDetecting;
      if (_isDetecting) {
        _cameraController?.startImageStream((CameraImage image) {
          if (!_isBusy) {
            _isBusy = true;
            _runModelOnFrame(image);
          }
        });
      } else {
        _cameraController?.stopImageStream();
        _recognitions = null;
      }
    });
  }

  void _switchCamera() {
    if (_backCameras.length > 1) {
      log("Switching camera...");
      _selectedBackCameraIndex = (_selectedBackCameraIndex + 1) % _backCameras.length;
      _initializeCamera().then((_) {
        if (_isDetecting) {
          _cameraController?.startImageStream((CameraImage image) {
            if (!_isBusy) {
              _isBusy = true;
              _runModelOnFrame(image);
            }
          });
        }
      });
    }
  }

  void _runModelOnFrame(CameraImage image) {
    if (_interpreter == null || _labels.isEmpty) {
      _isBusy = false;
      return;
    }

    _sendPort.send(IsolateData(image, _interpreter!.address, _labels));

    _isBusy = false;
  }

  @override
  void dispose() {
    log("dispose: Disposing camera controller and interpreter");
    _cameraController?.dispose();
    _interpreter?.close();
    _isolate.kill(priority: Isolate.immediate);
    _focusPointTimer?.cancel();
    super.dispose();
  }

  List<Widget> _renderBoxes(Size screen) {
    if (_recognitions == null) return [];

    return _recognitions!.map((re) {
      final Rect rect = re['rect'];
      return Positioned(
        left: rect.left,
        top: rect.top,
        width: rect.width,
        height: rect.height,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.blue, width: 2),
          ),
          child: Text(
            "${re["detectedClass"]} ${(re["confidenceInClass"] * 100).toStringAsFixed(0)}%",
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_modelLoaded) {
      return const SplashScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Object Detection'),
        actions: [
          if (_backCameras.length > 1)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Center(
                  child: Text('Cam: ${_selectedBackCameraIndex + 1}')),
            ),
          IconButton(
            icon: const Icon(Icons.switch_camera),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          CameraView(
            cameraController: _cameraController,
            onScaleStart: (details) {
              _baseZoomLevel = _currentZoomLevel;
            },
            onScaleUpdate: (details) {
              _currentZoomLevel = (_baseZoomLevel * details.scale)
                  .clamp(_minZoomLevel, _maxZoomLevel);
              _cameraController!.setZoomLevel(_currentZoomLevel);
              setState(() {});
            },
            onTapUp: (details) {
              final RenderBox renderBox = context.findRenderObject() as RenderBox;
              final Offset localPosition = renderBox.globalToLocal(details.globalPosition);
              final double x = localPosition.dx / renderBox.size.width;
              final double y = localPosition.dy / renderBox.size.height;

              _cameraController?.setFocusPoint(Offset(x, y));
              _cameraController?.setFocusMode(FocusMode.auto);

              _focusPointTimer?.cancel();
              if (mounted) {
                setState(() {
                  _focusPoint = localPosition;
                });
              }
              _focusPointTimer = Timer(const Duration(seconds: 2), () {
                if (mounted) {
                  setState(() {
                    _focusPoint = null;
                  });
                }
              });
            },
            currentZoomLevel: _currentZoomLevel,
            minZoomLevel: _minZoomLevel,
            maxZoomLevel: _maxZoomLevel,
            currentExposureOffset: _currentExposureOffset,
            minExposureOffset: _minExposureOffset,
            maxExposureOffset: _maxExposureOffset,
            onExposureChanged: (value) async {
              if (_cameraController != null) {
                await _cameraController!.setExposureOffset(value);
                if (mounted) {
                  setState(() {
                    _currentExposureOffset = value;
                  });
                }
              }
            },
            focusPoint: _focusPoint,
          ),
          ..._renderBoxes(MediaQuery.of(context).size),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _toggleDetection,
        child: Icon(_isDetecting ? Icons.stop : Icons.play_arrow),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
