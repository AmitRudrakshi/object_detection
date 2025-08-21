# Object Detector

A Flutter application for real-time object detection using the device's camera. This project utilizes the TensorFlow Lite plugin to run object detection models on both Android and iOS devices.

## Features

- Real-time object detection using the camera stream.
- Displays bounding boxes and labels for detected objects.
- Supports different TensorFlow Lite models.
- Simple and intuitive user interface.

## Getting Started

To get a local copy up and running, follow these simple steps.

### Prerequisites

- Flutter SDK: [https://flutter.dev/docs/get-started/install](https://flutter.dev/docs/get-started/install)
- An editor like Android Studio or VS Code with the Flutter plugin.

### Installation

1.  Clone the repo
    ```sh
    git clone https://github.com/your_username/object_detector.git
    ```
2.  Install packages
    ```sh
    flutter pub get
    ```
3.  Run the app
    ```sh
    flutter run
    ```

## Models

The application uses TensorFlow Lite models for object detection. The models are located in the `assets` directory.

- `yolov2_tiny.tflite`
- `yolov5s_f16.tflite`

## Project Structure

The project is structured as follows:

- `lib/main.dart`: The main entry point of the application.
- `lib/presentation/screens`: Contains the screens of the application (e.g., `home.dart`, `splash_screen.dart`).
- `lib/presentation/widgets`: Contains the widgets used in the application (e.g., `camera_view.dart`, `recognition_painter.dart`).
- `lib/utils`: Contains utility classes (e.g., `isolate_utils.dart` for running inference in a separate isolate).
- `assets`: Contains the TensorFlow Lite models and labels.

## Contributing

Contributions are what make the open source community such an amazing place to learn, inspire, and create. Any contributions you make are **greatly appreciated**.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request
