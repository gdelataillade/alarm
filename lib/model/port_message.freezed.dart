// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'port_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#custom-getters-and-methods');

/// @nodoc
mixin _$PortMessage {
  MessageType get type => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;
  NotificationResponse? get notificationResponse =>
      throw _privateConstructorUsedError;

  @JsonKey(ignore: true)
  $PortMessageCopyWith<PortMessage> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PortMessageCopyWith<$Res> {
  factory $PortMessageCopyWith(
          PortMessage value, $Res Function(PortMessage) then) =
      _$PortMessageCopyWithImpl<$Res, PortMessage>;
  @useResult
  $Res call(
      {MessageType type,
      String? message,
      NotificationResponse? notificationResponse});
}

/// @nodoc
class _$PortMessageCopyWithImpl<$Res, $Val extends PortMessage>
    implements $PortMessageCopyWith<$Res> {
  _$PortMessageCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? message = freezed,
    Object? notificationResponse = freezed,
  }) {
    return _then(_value.copyWith(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MessageType,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      notificationResponse: freezed == notificationResponse
          ? _value.notificationResponse
          : notificationResponse // ignore: cast_nullable_to_non_nullable
              as NotificationResponse?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$_PortMessageCopyWith<$Res>
    implements $PortMessageCopyWith<$Res> {
  factory _$$_PortMessageCopyWith(
          _$_PortMessage value, $Res Function(_$_PortMessage) then) =
      __$$_PortMessageCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {MessageType type,
      String? message,
      NotificationResponse? notificationResponse});
}

/// @nodoc
class __$$_PortMessageCopyWithImpl<$Res>
    extends _$PortMessageCopyWithImpl<$Res, _$_PortMessage>
    implements _$$_PortMessageCopyWith<$Res> {
  __$$_PortMessageCopyWithImpl(
      _$_PortMessage _value, $Res Function(_$_PortMessage) _then)
      : super(_value, _then);

  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? message = freezed,
    Object? notificationResponse = freezed,
  }) {
    return _then(_$_PortMessage(
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as MessageType,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      notificationResponse: freezed == notificationResponse
          ? _value.notificationResponse
          : notificationResponse // ignore: cast_nullable_to_non_nullable
              as NotificationResponse?,
    ));
  }
}

/// @nodoc

class _$_PortMessage implements _PortMessage {
  const _$_PortMessage(
      {required this.type, this.message, this.notificationResponse});

  @override
  final MessageType type;
  @override
  final String? message;
  @override
  final NotificationResponse? notificationResponse;

  @override
  String toString() {
    return 'PortMessage._(type: $type, message: $message, notificationResponse: $notificationResponse)';
  }

  @override
  bool operator ==(dynamic other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$_PortMessage &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.notificationResponse, notificationResponse) ||
                other.notificationResponse == notificationResponse));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, type, message, notificationResponse);

  @JsonKey(ignore: true)
  @override
  @pragma('vm:prefer-inline')
  _$$_PortMessageCopyWith<_$_PortMessage> get copyWith =>
      __$$_PortMessageCopyWithImpl<_$_PortMessage>(this, _$identity);
}

abstract class _PortMessage implements PortMessage {
  const factory _PortMessage(
      {required final MessageType type,
      final String? message,
      final NotificationResponse? notificationResponse}) = _$_PortMessage;

  @override
  MessageType get type;
  @override
  String? get message;
  @override
  NotificationResponse? get notificationResponse;
  @override
  @JsonKey(ignore: true)
  _$$_PortMessageCopyWith<_$_PortMessage> get copyWith =>
      throw _privateConstructorUsedError;
}
