class Entrance {
  const Entrance({
    required this.id,
    required this.buildingId,
    required this.nodeId,
    required this.label,
    required this.isPrimary,
  });

  final String id;
  final String buildingId;
  final String nodeId;
  final String label;
  final bool isPrimary;

  factory Entrance.fromJson(Map<String, dynamic> json, String path) {
    final id = json['id'];
    final buildingId = json['buildingId'];
    final nodeId = json['nodeId'];
    final label = json['label'];
    final primary = json['isPrimary'];
    if (id is! String || id.isEmpty) {
      throw FormatException('$path.id is required');
    }
    if (buildingId is! String || buildingId.isEmpty) {
      throw FormatException('$path.buildingId is required');
    }
    if (nodeId is! String || nodeId.isEmpty) {
      throw FormatException('$path.nodeId is required');
    }
    if (label is! String || label.isEmpty) {
      throw FormatException('$path.label is required');
    }
    if (primary is! bool) {
      throw FormatException('$path.isPrimary must be boolean');
    }
    return Entrance(
      id: id,
      buildingId: buildingId,
      nodeId: nodeId,
      label: label,
      isPrimary: primary,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'buildingId': buildingId,
    'nodeId': nodeId,
    'label': label,
    'isPrimary': isPrimary,
  };
}
