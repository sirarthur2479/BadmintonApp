import 'dart:io';
import 'package:flutter/painting.dart';

/// Device build: local paths are real files.
ImageProvider localImageProvider(String path) => FileImage(File(path));
