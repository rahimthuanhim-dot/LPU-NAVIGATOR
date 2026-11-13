class AppConstants {
  static const styleAsset = 'assets/map/style.json';
  static const campusJsonAsset = 'assets/data/campus.json';
  static const campusLayersFile = 'campus_layers.geojson';
  static const glyphAssetPrefix = 'assets/map/glyphs/';
  static const glyphRange = '0-255.pbf';
  static const fontStack = 'NotoSansRegular';
  static const storageToken = '__APP_STORAGE__';
  static const minimumGlyphFileBytes = 1024;
  static const styleLoadTimeout = Duration(seconds: 15);
  static const defaultMapZoom = 16.0;

  const AppConstants._();
}
