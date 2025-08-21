import 'dart:async';
import 'dart:developer';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class IsolateData {
  final CameraImage cameraImage;
  final int interpreterAddress;
  final List<String> labels;

  IsolateData(this.cameraImage, this.interpreterAddress, this.labels);
}

void runInference(SendPort sendPort) {
  final ReceivePort receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic data) async {
    final IsolateData isolateData = data as IsolateData;
    final Interpreter interpreter = Interpreter.fromAddress(isolateData.interpreterAddress);
    final List<String> labels = isolateData.labels;

    final img.Image resizedImage = await _processCameraImage(isolateData.cameraImage);
    final Float32List inputBytes = _imageToFloat32List(resizedImage);
    final input = inputBytes.reshape([1, 416, 416, 3]);

    var output = List.filled(1 * 13 * 13 * 425, 0.0).reshape([1, 13, 13, 425]);

    try {
      interpreter.run(input, output);
    } catch (e) {
      log('Error running model in isolate: $e');
    }

    final List<dynamic> recognitions = _processOutput(output, isolateData.cameraImage.width, isolateData.cameraImage.height, labels);
    sendPort.send(recognitions);
  });
}

Future<img.Image> _processCameraImage(CameraImage image) async {
  final img.Image? convertedImage = await _convertYUV420toRGB(image);
  if (convertedImage == null) {
    throw Exception("Image conversion failed");
  }
  return img.copyResize(convertedImage, width: 416, height: 416);
}

Future<img.Image?> _convertYUV420toRGB(CameraImage image) async {
  final int width = image.width;
  final int height = image.height;
  final int uvRowStride = image.planes[1].bytesPerRow;
  final int? uvPixelStride = image.planes[1].bytesPerPixel;

  if (uvPixelStride == null) {
    return null;
  }

  var yuvImage = img.Image(width: width, height: height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int uvIndex = uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
      final int index = y * width + x;

      final yp = image.planes[0].bytes[index];
      final up = image.planes[1].bytes[uvIndex];
      final vp = image.planes[2].bytes[uvIndex];

      int r = (yp + vp * 1.402).round().clamp(0, 255);
      int g = (yp - up * 0.344 - vp * 0.714).round().clamp(0, 255);
      int b = (yp + up * 1.772).round().clamp(0, 255);

      yuvImage.setPixelRgba(x, y, r, g, b, 255);
    }
  }
  return yuvImage;
}

Float32List _imageToFloat32List(img.Image image) {
  var convertedBytes = Float32List(1 * 416 * 416 * 3);
  var buffer = Float32List.view(convertedBytes.buffer);
  int pixelIndex = 0;
  for (var i = 0; i < 416; i++) {
    for (var j = 0; j < 416; j++) {
      var pixel = image.getPixel(j, i);
      buffer[pixelIndex++] = pixel.r / 255.0;
      buffer[pixelIndex++] = pixel.g / 255.0;
      buffer[pixelIndex++] = pixel.b / 255.0;
    }
  }
  return convertedBytes;
}

List<dynamic> _processOutput(List<dynamic> output, int imageWidth, int imageHeight, List<String> labels) {
  final List<Rect> boxes = [];
  final List<double> scores = [];
  final List<int> classIndexes = [];

  final List<double> anchors = [1.08, 1.19, 3.42, 4.41, 6.63, 11.38, 9.42, 5.11, 16.62, 10.52];

  for (int i = 0; i < 13; i++) {
    for (int j = 0; j < 13; j++) {
      for (int k = 0; k < 5; k++) {
        final double confidence = _sigmoid(output[0][i][j][k * 85 + 4]);

        if (confidence > 0.1) {
          final double x = (j + _sigmoid(output[0][i][j][k * 85 + 0])) / 13.0;
          final double y = (i + _sigmoid(output[0][i][j][k * 85 + 1])) / 13.0;
          final double w = (math.exp(output[0][i][j][k * 85 + 2]) * anchors[2 * k]) / 13.0;
          final double h = (math.exp(output[0][i][j][k * 85 + 3]) * anchors[2 * k + 1]) / 13.0;

          final Rect rect = Rect.fromLTWH(
            (x - w / 2) * imageWidth,
            (y - h / 2) * imageHeight,
            w * imageWidth,
            h * imageHeight,
          );

          final List<double> classProbabilities = List<double>.from(output[0][i][j].sublist(k * 85 + 5, (k + 1) * 85));
          final int bestClassIndex = _getBestClassIndex(classProbabilities);
          final double bestClassScore = classProbabilities[bestClassIndex];

          if (bestClassScore > 0.1) {
            boxes.add(rect);
            scores.add(confidence * bestClassScore);
            classIndexes.add(bestClassIndex);
          }
        }
      }
    }
  }

  final List<int> nmsIndexes = _nonMaxSuppression(boxes, scores, 0.5);

  final List<dynamic> recognitions = [];
  for (int index in nmsIndexes) {
    recognitions.add({
      'rect': boxes[index],
      'confidenceInClass': scores[index],
      'detectedClass': labels[classIndexes[index]],
    });
  }
  return recognitions;
}

double _sigmoid(double x) {
  return 1 / (1 + math.exp(-x));
}

int _getBestClassIndex(List<double> probabilities) {
  double maxScore = 0;
  int bestIndex = -1;
  for (int i = 0; i < probabilities.length; i++) {
    if (probabilities[i] > maxScore) {
      maxScore = probabilities[i];
      bestIndex = i;
    }
  }
  return bestIndex;
}

List<int> _nonMaxSuppression(List<Rect> boxes, List<double> scores, double threshold) {
  List<int> indexes = List.generate(boxes.length, (i) => i);
  indexes.sort((a, b) => scores[b].compareTo(scores[a]));

  List<int> selectedIndexes = [];
  while (indexes.isNotEmpty) {
    int currentIndex = indexes.removeAt(0);
    selectedIndexes.add(currentIndex);

    List<int> remainingIndexes = [];
    for (int index in indexes) {
      double iou = _calculateIoU(boxes[currentIndex], boxes[index]);
      if (iou < threshold) {
        remainingIndexes.add(index);
      }
    }
    indexes = remainingIndexes;
  }
  return selectedIndexes;
}

double _calculateIoU(Rect rect1, Rect rect2) {
  final double intersectionLeft = math.max(rect1.left, rect2.left);
  final double intersectionTop = math.max(rect1.top, rect2.top);
  final double intersectionRight = math.min(rect1.right, rect2.right);
  final double intersectionBottom = math.min(rect1.bottom, rect2.bottom);

  final double intersectionArea = math.max(0, intersectionRight - intersectionLeft) * math.max(0, intersectionBottom - intersectionTop);
  final double unionArea = rect1.width * rect1.height + rect2.width * rect2.height - intersectionArea;

  return intersectionArea / unionArea;
}
