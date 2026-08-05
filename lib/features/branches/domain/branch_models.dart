import 'package:equatable/equatable.dart';

class Branch extends Equatable {
  final String id;
  final String name;
  final String address;
  final String phone;
  final bool isActive;
  final int registersCount;
  final int employeesCount;

  const Branch({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.isActive = true,
    this.registersCount = 0,
    this.employeesCount = 0,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: (json['id'] ?? '').toString(),
      name: json['name']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      isActive: json['is_active'] as bool? ?? true,
      registersCount: (json['registers_count'] as num?)?.toInt() ?? 0,
      employeesCount: (json['employees_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'is_active': isActive,
      'registers_count': registersCount,
      'employees_count': employeesCount,
    };
  }

  @override
  List<Object?> get props => [
    id,
    name,
    address,
    phone,
    isActive,
    registersCount,
    employeesCount,
  ];
}
