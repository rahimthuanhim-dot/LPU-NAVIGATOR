import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

const _styleAsset = 'assets/map/style.json';
const _geoJsonAsset = 'assets/map/test.geojson';
const _glyphFontStack = 'NotoSansRegular';
const _glyphAsset = 'assets/map/glyphs/$_glyphFontStack/0-255.pbf';
const _storageToken = '__APP_STORAGE__';
const _minimumGlyphFileBytes = 1024;
const _styleLoadTimeout = Duration(seconds: 15);

void main() {
  runApp(const MapSpikeApp());
}

class MapSpikeApp extends StatelessWidget {
  const MapSpikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LPU Navigator Offline Map Spike',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const OfflineMapScreen(),
    );
  }
}

class OfflineMapScreen extends StatefulWidget {
  const OfflineMapScreen({super.key});

  @override
  State<OfflineMapScreen> createState() => _OfflineMapScreenState();
}

class _OfflineMapScreenState extends State<OfflineMapScreen> {
  String? _stylePath;
  String? _error;
  Timer? _styleLoadTimer;
  bool _styleLoaded = false;

  @override
  void initState() {
    super.initState();
    _prepareMapFiles();
  }

  Future<void> _prepareMapFiles() async {
    try {
      final storage = Directory('${Directory.systemTemp.path}/lpu_navigator_map');
      final glyphDirectory =
          Directory('${storage.path}/glyphs/$_glyphFontStack');
      await glyphDirectory.create(recursive: true);

      final styleFile = File('${storage.path}/style.json');
      final geoJsonFile = File('${storage.path}/test.geojson');
      final glyphFile = File('${glyphDirectory.path}/0-255.pbf');

      final styleText = await _readAssetText(_styleAsset);
      final styleJson = jsonDecode(styleText);
      if (styleJson is! Map<String, dynamic>) {
        throw const FormatException('style.json must contain a JSON object');
      }
      _validateOfflineUrls(styleJson);

      final geoJsonText = await _readAssetText(_geoJsonAsset);
      final geoJson = jsonDecode(geoJsonText);
      if (geoJson is! Map<String, dynamic> ||
          geoJson['type'] != 'FeatureCollection') {
        throw const FormatException('test.geojson must be a FeatureCollection');
      }

      await styleFile.writeAsString(
        styleText.replaceAll(_storageToken, storage.path),
      );
      await geoJsonFile.writeAsString(geoJsonText);
      await _copyAsset(_glyphAsset, glyphFile);

      await _validateGlyphAssets(styleJson, storage);

      if (mounted) {
        setState(() {
          _stylePath = styleFile.path;
          _styleLoadTimer = Timer(_styleLoadTimeout, () {
            if (mounted && !_styleLoaded) {
              setState(
                () => _error =
                    'Map style did not finish loading within '
                    '${_styleLoadTimeout.inSeconds} seconds.',
              );
            }
          });
        });
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _error = 'Offline map assets could not be loaded:\n$error');
      }
    }
  }

  Future<String> _readAssetText(String asset) async {
    try {
      return await rootBundle.loadString(asset);
    } on Object catch (error) {
      throw StateError('Missing asset $asset: $error');
    }
  }

  Future<void> _copyAsset(String asset, File destination) async {
    try {
      final data = await rootBundle.load(asset);
      await destination.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    } on Object catch (error) {
      throw StateError('Missing asset $asset: $error');
    }
  }

  Future<void> _validateGlyphAssets(
    Map<String, dynamic> styleJson,
    Directory storage,
  ) async {
    final fontStacks = <String>{};
    final layers = styleJson['layers'];
    if (layers is! List) {
      throw const FormatException('style.json layers must be an array');
    }

    for (final layer in layers) {
      if (layer is! Map) {
        continue;
      }
      final layout = layer['layout'];
      if (layout is! Map) {
        continue;
      }
      final textFont = layout['text-font'];
      if (textFont is List) {
        fontStacks.addAll(textFont.whereType<String>());
      }
    }

    for (final fontStack in fontStacks) {
      final glyphFile = File(
        '${storage.path}/glyphs/$fontStack/0-255.pbf',
      );
      if (!await glyphFile.exists() ||
          await glyphFile.length() < _minimumGlyphFileBytes) {
        throw FormatException(
          'Missing glyph file for text font "$fontStack": ${glyphFile.path}',
        );
      }
    }
  }

  void _validateOfflineUrls(Object? value) {
    if (value is String) {
      final schemes = RegExp(
        r'[A-Za-z][A-Za-z0-9+.-]*://',
      ).allMatches(value);
      for (final scheme in schemes) {
        if (scheme.group(0) != 'file://') {
          throw FormatException('style.json contains a non-file URL: $value');
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

  void _onStyleLoaded() {
    _styleLoadTimer?.cancel();
    if (mounted) {
      setState(() => _styleLoaded = true);
    }
  }

  @override
  void dispose() {
    _styleLoadTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final stylePath = _stylePath;
    return Scaffold(
      appBar: AppBar(title: const Text('Offline map spike')),
      body: error != null
          ? _ErrorView(message: error)
          : stylePath == null
              ? const Center(child: CircularProgressIndicator())
              : MapLibreMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(31.25, 75.70),
                    zoom: 15,
                  ),
                  styleString: stylePath,
                  onStyleLoadedCallback: _onStyleLoaded,
                  compassEnabled: true,
                  attributionEnabled: false,
                ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    );
  }
}
