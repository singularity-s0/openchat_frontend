// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ChatThread _$ChatThreadFromJson(Map<String, dynamic> json) => ChatThread(
      count: json['count'] as int,
      name: json['name'] as String,
      created_at: json['created_at'] as String,
      updated_at: json['updated_at'] as String,
      id: json['id'] as int,
      user_id: json['user_id'] as int,
      records: (json['records'] as List<dynamic>?)
          ?.map((e) => ChatRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$ChatThreadToJson(ChatThread instance) =>
    <String, dynamic>{
      'count': instance.count,
      'name': instance.name,
      'created_at': instance.created_at,
      'updated_at': instance.updated_at,
      'id': instance.id,
      'user_id': instance.user_id,
      'records': instance.records,
    };

ChatRecord _$ChatRecordFromJson(Map<String, dynamic> json) => ChatRecord(
      chat_id: json['chat_id'] as int,
      id: json['id'] as int,
      feedback: json['feedback'] as String?,
      like_data: json['like_data'] as int,
      created_at: json['created_at'] as String,
      request: json['request'] as String,
      response: json['response'] as String,
    );

Map<String, dynamic> _$ChatRecordToJson(ChatRecord instance) =>
    <String, dynamic>{
      'chat_id': instance.chat_id,
      'id': instance.id,
      'feedback': instance.feedback,
      'like_data': instance.like_data,
      'created_at': instance.created_at,
      'request': instance.request,
      'response': instance.response,
    };

WSInferResponse _$WSInferResponseFromJson(Map<String, dynamic> json) =>
    WSInferResponse(
      json['status'] as int?,
      json['status_code'] as int?,
      json['uuid'] as String?,
      json['offset'] as int?,
      json['output'] as String?,
    );

Map<String, dynamic> _$WSInferResponseToJson(WSInferResponse instance) =>
    <String, dynamic>{
      'status': instance.status,
      'status_code': instance.status_code,
      'uuid': instance.uuid,
      'offset': instance.offset,
      'output': instance.output,
    };
