/// Named tile sources used in the map screen and pre-download.
///
/// Note: Esri World Imagery requires attribution per the Esri terms of use.
enum TileSource {
  osm(
    id: 'osm',
    label: 'OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    attribution: '© OpenStreetMap contributors',
    maxZoom: 19,
  ),
  topo(
    id: 'opentopomap',
    label: 'OpenTopoMap',
    urlTemplate: 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png',
    attribution: '© OpenTopoMap (CC-BY-SA), © OpenStreetMap contributors',
    maxZoom: 17,
    subdomains: ['a', 'b', 'c'],
  ),
  esriSat(
    id: 'esri_sat',
    label: 'Esri Satellite',
    urlTemplate:
        'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    attribution:
        'Tiles © Esri — Source: Esri, Maxar, Earthstar Geographics, and the GIS User Community',
    maxZoom: 19,
  );

  const TileSource({
    required this.id,
    required this.label,
    required this.urlTemplate,
    required this.attribution,
    required this.maxZoom,
    this.subdomains = const [],
  });

  final String id;
  final String label;
  final String urlTemplate;
  final String attribution;
  final int maxZoom;
  final List<String> subdomains;

  static TileSource fromId(String id) =>
      TileSource.values.firstWhere((t) => t.id == id, orElse: () => TileSource.topo);
}
