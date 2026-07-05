import 'package:flutter/painting.dart';

/// Web build: image_picker returns blob URLs, which load over the network
/// stack (dart:io is unavailable on web).
ImageProvider localImageProvider(String path) => NetworkImage(path);
