import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../../core/constants.dart';
import '../../core/problems.dart';
import '../../data/models/campus_dataset.dart';
import 'map_layer_builder.dart';

typedef MapAssetLoader = Future<ByteData> Function(String assetPath);

class MapProvisioningResult {
  const MapProvisioningResult({
    this.stylePath,
    this.problems = const <MapProblem>[],
  });

  final String? stylePath;
  final List<MapProblem> problems;

  bool get isReady => stylePath != null && problems.isEmpty;
}

class MapAssetProvisioner {
  MapAssetProvisioner({Directory? storage, MapAssetLoader? assetLoader})
    : storage =
          storage ??
          Directory('${Directory.systemTemp.path}/lpu_navigator_map'),
      assetLoader = assetLoader ?? rootBundle.load;

  // TODO: Move the default storage to the app-support directory later.
  final Directory storage;
  final MapAssetLoader assetLoader;

  Future<MapProvisioningResult> provision({
    required CampusDataset dataset,
  }) async {
    try {
      await storage.create(recursive: true);
      final styleText = await _loadText(AppConstants.styleAsset);
      final styleJson = _decodeObject(styleText, 'invalid_style_json');
      _validateOfflineUrls(styleJson);

      final geoJsonText = MapLayerBuilder().buildJson(dataset);

      final fontStacks = _fontStacks(styleJson);
      final styleFile = File('${storage.path}/style.json');
      final geoJsonFile = File(
        '${storage.path}/${AppConstants.campusLayersFile}',
      );
      await styleFile.writeAsString(
        styleText.replaceAll(AppConstants.storageToken, storage.path),
      );
      await geoJsonFile.writeAsString(geoJsonText);

      for (final fontStack in fontStacks) {
        final asset =
            '${AppConstants.glyphAssetPrefix}$fontStack/'
            '${AppConstants.glyphRange}';
        final glyphFile = File(
          '${storage.path}/glyphs/$fontStack/${AppConstants.glyphRange}',
        );
        await glyphFile.parent.create(recursive: true);
        final bytes = await _loadBytes(asset);
        await glyphFile.writeAsBytes(bytes, flush: true);
      }

      for (final fontStack in fontStacks) {
        final glyphFile = File(
          '${storage.path}/glyphs/$fontStack/${AppConstants.glyphRange}',
        );
        if (!await glyphFile.exists() ||
            await glyphFile.length() < AppConstants.minimumGlyphFileBytes) {
          throw _ProvisioningFailure(
            MapProblem(
              code: 'missing_glyph',
              message: 'Glyph file for "$fontStack" is missing or too small.',
              path: glyphFile.path,
            ),
          );
        }
      }
      return MapProvisioningResult(stylePath: styleFile.path);
    } on _ProvisioningFailure catch (failure) {
      return MapProvisioningResult(problems: <MapProblem>[failure.problem]);
    } on Object catch (error) {
      return MapProvisioningResult(
        problems: <MapProblem>[
          MapProblem(
            code: 'provisioning_failed',
            message: 'Offline map assets could not be provisioned: $error',
          ),
        ],
      );
    }
  }

  Future<String> _loadText(String assetPath) async {
    final bytes = await _loadBytes(assetPath);
    try {
      return utf8.decode(bytes);
    } on FormatException catch (error) {
      throw _ProvisioningFailure(
        MapProblem(
          code: 'invalid_asset_encoding',
          message: 'Asset "$assetPath" is not valid UTF-8: $error',
          path: assetPath,
        ),
      );
    }
  }

  Future<Uint8List> _loadBytes(String assetPath) async {
    try {
      final data = await assetLoader(assetPath);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } on Object catch (error) {
      throw _ProvisioningFailure(
        MapProblem(
          code: 'missing_asset',
          message: 'Missing asset "$assetPath": $error',
          path: assetPath,
        ),
      );
    }
  }

  Map<String, dynamic> _decodeObject(String text, String code) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } on FormatException catch (error) {
      throw _ProvisioningFailure(
        MapProblem(code: code, message: 'Invalid JSON: $error'),
      );
    }
    throw _ProvisioningFailure(
      MapProblem(code: code, message: 'JSON must contain an object.'),
    );
  }

  Set<String> _fontStacks(Map<String, dynamic> styleJson) {
    final layers = styleJson['layers'];
    if (layers is! List) {
      throw const _ProvisioningFailure(
        MapProblem(
          code: 'invalid_style_json',
          message: 'style.json layers must be an array.',
        ),
      );
    }
    final fontStacks = <String>{};
    for (final layer in layers) {
      if (layer is! Map) {
        continue;
      }
      final layout = layer['layout'];
      final textFont = layout is Map ? layout['text-font'] : null;
      if (textFont is List) {
        fontStacks.addAll(textFont.whereType<String>());
      }
    }
    return fontStacks;
  }

  void _validateOfflineUrls(Object? value) {
    if (value is String) {
      for (final match in RegExp(
        r'[A-Za-z][A-Za-z0-9+.-]*://',
      ).allMatches(value)) {
        if (match.group(0) != 'file://') {
          throw _ProvisioningFailure(
            MapProblem(
              code: 'non_file_url',
              message: 'style.json contains a non-file URL: $value',
              path: value,
            ),
          );
        }
      }
    } else if (value is Map) {
      for (final item in value.values) {
        _validateOfflineUrls(item);
      }
    } else if (value is Iterable) {
      for (final item in value) {
        _validateOfflineUrls(item);
      }
    }
  }
}

class _ProvisioningFailure implements Exception {
  const _ProvisioningFailure(this.problem);

  final MapProblem problem;
}
