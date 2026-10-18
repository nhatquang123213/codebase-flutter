import 'package:json_annotation/json_annotation.dart';

import '../../domain/entities/user.dart';

part 'user_model.g.dart';

/// Wire format of a user. Run `make gen` after changing fields.
@JsonSerializable()
class UserModel {
  const UserModel({required this.id, required this.email, required this.name});

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);

  @JsonKey(fromJson: _idFromJson)
  final String id;
  final String email;
  @JsonKey(defaultValue: '')
  final String name;

  Map<String, dynamic> toJson() => _$UserModelToJson(this);

  User toEntity() => User(id: id, email: email, name: name);
}

/// Backends disagree on whether ids are numbers or strings; accept both.
String _idFromJson(Object? value) => value.toString();
