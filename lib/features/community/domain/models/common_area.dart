class CommonArea {
  final String id;
  final String name;
  final String description;
  final String iconPath; // For simple simulation, we'll use icon names or local images
  final int capacity;
  final String rules;

  CommonArea({
    required this.id,
    required this.name,
    required this.description,
    required this.iconPath,
    required this.capacity,
    required this.rules,
  });
}

class AvailabilitySlot {
  final DateTime date;
  final bool isAvailable;
  final String? bookedByUnit;

  AvailabilitySlot({
    required this.date,
    this.isAvailable = true,
    this.bookedByUnit,
  });
}
