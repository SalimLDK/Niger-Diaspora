import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

part 'embassy_employee_model.freezed.dart';
part 'embassy_employee_model.g.dart';

/// Employee roles at the embassy
enum EmbassyEmployeeRole {
  ambassador,
  consul,
  counselor,
  attache,
  secretary,
  administrator,
  agent,
  other,
}

@freezed
class EmbassyEmployeeModel with _$EmbassyEmployeeModel {
  const EmbassyEmployeeModel._();

  const factory EmbassyEmployeeModel({
    required String id,
    required String embassyId,
    required String name,
    required String role,
    String? title, // e.g., "Ambassador Extraordinary and Plenipotentiary"
    String? department, // e.g., "Consular Services", "Visa Section"
    String? email,
    String? phone,
    String? photoUrl,
    @Default(true) bool isPublic, // Whether to show in public directory
    @Default(true) bool isActive,
    String? bio,
    @Default([]) List<String> languages,
    @Default([]) List<String> responsibilities,
    // Link to user account if exists
    String? linkedUserId,
  }) = _EmbassyEmployeeModel;

  factory EmbassyEmployeeModel.fromJson(Map<String, dynamic> json) =>
      _$EmbassyEmployeeModelFromJson(json);

  factory EmbassyEmployeeModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    data['id'] = doc.id;
    return EmbassyEmployeeModel.fromJson(data);
  }

  Map<String, dynamic> toFirestore() {
    final json = toJson();
    json.remove('id');
    return json;
  }
}
