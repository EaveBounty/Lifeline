// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $RecordsTable extends Records with TableInfo<$RecordsTable, RecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _organizationMeta = const VerificationMeta(
    'organization',
  );
  @override
  late final GeneratedColumn<String> organization = GeneratedColumn<String>(
    'organization',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locationMeta = const VerificationMeta(
    'location',
  );
  @override
  late final GeneratedColumn<String> location = GeneratedColumn<String>(
    'location',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<String> startDate = GeneratedColumn<String>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<String> endDate = GeneratedColumn<String>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyJsonMeta = const VerificationMeta(
    'bodyJson',
  );
  @override
  late final GeneratedColumn<String> bodyJson = GeneratedColumn<String>(
    'body_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    category,
    title,
    organization,
    role,
    location,
    startDate,
    endDate,
    description,
    bodyJson,
    updatedAt,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'records';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('organization')) {
      context.handle(
        _organizationMeta,
        organization.isAcceptableOrUnknown(
          data['organization']!,
          _organizationMeta,
        ),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('location')) {
      context.handle(
        _locationMeta,
        location.isAcceptableOrUnknown(data['location']!, _locationMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('body_json')) {
      context.handle(
        _bodyJsonMeta,
        bodyJson.isAcceptableOrUnknown(data['body_json']!, _bodyJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_bodyJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      organization: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      ),
      location: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}location'],
      ),
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}start_date'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}end_date'],
      ),
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      bodyJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $RecordsTable createAlias(String alias) {
    return $RecordsTable(attachedDatabase, alias);
  }
}

class RecordRow extends DataClass implements Insertable<RecordRow> {
  final String id;
  final String category;
  final String title;
  final String? organization;
  final String? role;
  final String? location;
  final String? startDate;
  final String? endDate;
  final String description;
  final String bodyJson;
  final DateTime updatedAt;
  final int sortOrder;
  const RecordRow({
    required this.id,
    required this.category,
    required this.title,
    this.organization,
    this.role,
    this.location,
    this.startDate,
    this.endDate,
    required this.description,
    required this.bodyJson,
    required this.updatedAt,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['category'] = Variable<String>(category);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || organization != null) {
      map['organization'] = Variable<String>(organization);
    }
    if (!nullToAbsent || role != null) {
      map['role'] = Variable<String>(role);
    }
    if (!nullToAbsent || location != null) {
      map['location'] = Variable<String>(location);
    }
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<String>(startDate);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<String>(endDate);
    }
    map['description'] = Variable<String>(description);
    map['body_json'] = Variable<String>(bodyJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  RecordsCompanion toCompanion(bool nullToAbsent) {
    return RecordsCompanion(
      id: Value(id),
      category: Value(category),
      title: Value(title),
      organization: organization == null && nullToAbsent
          ? const Value.absent()
          : Value(organization),
      role: role == null && nullToAbsent ? const Value.absent() : Value(role),
      location: location == null && nullToAbsent
          ? const Value.absent()
          : Value(location),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      description: Value(description),
      bodyJson: Value(bodyJson),
      updatedAt: Value(updatedAt),
      sortOrder: Value(sortOrder),
    );
  }

  factory RecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordRow(
      id: serializer.fromJson<String>(json['id']),
      category: serializer.fromJson<String>(json['category']),
      title: serializer.fromJson<String>(json['title']),
      organization: serializer.fromJson<String?>(json['organization']),
      role: serializer.fromJson<String?>(json['role']),
      location: serializer.fromJson<String?>(json['location']),
      startDate: serializer.fromJson<String?>(json['startDate']),
      endDate: serializer.fromJson<String?>(json['endDate']),
      description: serializer.fromJson<String>(json['description']),
      bodyJson: serializer.fromJson<String>(json['bodyJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'category': serializer.toJson<String>(category),
      'title': serializer.toJson<String>(title),
      'organization': serializer.toJson<String?>(organization),
      'role': serializer.toJson<String?>(role),
      'location': serializer.toJson<String?>(location),
      'startDate': serializer.toJson<String?>(startDate),
      'endDate': serializer.toJson<String?>(endDate),
      'description': serializer.toJson<String>(description),
      'bodyJson': serializer.toJson<String>(bodyJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  RecordRow copyWith({
    String? id,
    String? category,
    String? title,
    Value<String?> organization = const Value.absent(),
    Value<String?> role = const Value.absent(),
    Value<String?> location = const Value.absent(),
    Value<String?> startDate = const Value.absent(),
    Value<String?> endDate = const Value.absent(),
    String? description,
    String? bodyJson,
    DateTime? updatedAt,
    int? sortOrder,
  }) => RecordRow(
    id: id ?? this.id,
    category: category ?? this.category,
    title: title ?? this.title,
    organization: organization.present ? organization.value : this.organization,
    role: role.present ? role.value : this.role,
    location: location.present ? location.value : this.location,
    startDate: startDate.present ? startDate.value : this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    description: description ?? this.description,
    bodyJson: bodyJson ?? this.bodyJson,
    updatedAt: updatedAt ?? this.updatedAt,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  RecordRow copyWithCompanion(RecordsCompanion data) {
    return RecordRow(
      id: data.id.present ? data.id.value : this.id,
      category: data.category.present ? data.category.value : this.category,
      title: data.title.present ? data.title.value : this.title,
      organization: data.organization.present
          ? data.organization.value
          : this.organization,
      role: data.role.present ? data.role.value : this.role,
      location: data.location.present ? data.location.value : this.location,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      description: data.description.present
          ? data.description.value
          : this.description,
      bodyJson: data.bodyJson.present ? data.bodyJson.value : this.bodyJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordRow(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('title: $title, ')
          ..write('organization: $organization, ')
          ..write('role: $role, ')
          ..write('location: $location, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('description: $description, ')
          ..write('bodyJson: $bodyJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    category,
    title,
    organization,
    role,
    location,
    startDate,
    endDate,
    description,
    bodyJson,
    updatedAt,
    sortOrder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordRow &&
          other.id == this.id &&
          other.category == this.category &&
          other.title == this.title &&
          other.organization == this.organization &&
          other.role == this.role &&
          other.location == this.location &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.description == this.description &&
          other.bodyJson == this.bodyJson &&
          other.updatedAt == this.updatedAt &&
          other.sortOrder == this.sortOrder);
}

class RecordsCompanion extends UpdateCompanion<RecordRow> {
  final Value<String> id;
  final Value<String> category;
  final Value<String> title;
  final Value<String?> organization;
  final Value<String?> role;
  final Value<String?> location;
  final Value<String?> startDate;
  final Value<String?> endDate;
  final Value<String> description;
  final Value<String> bodyJson;
  final Value<DateTime> updatedAt;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const RecordsCompanion({
    this.id = const Value.absent(),
    this.category = const Value.absent(),
    this.title = const Value.absent(),
    this.organization = const Value.absent(),
    this.role = const Value.absent(),
    this.location = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.description = const Value.absent(),
    this.bodyJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordsCompanion.insert({
    required String id,
    required String category,
    required String title,
    this.organization = const Value.absent(),
    this.role = const Value.absent(),
    this.location = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.description = const Value.absent(),
    required String bodyJson,
    required DateTime updatedAt,
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       category = Value(category),
       title = Value(title),
       bodyJson = Value(bodyJson),
       updatedAt = Value(updatedAt);
  static Insertable<RecordRow> custom({
    Expression<String>? id,
    Expression<String>? category,
    Expression<String>? title,
    Expression<String>? organization,
    Expression<String>? role,
    Expression<String>? location,
    Expression<String>? startDate,
    Expression<String>? endDate,
    Expression<String>? description,
    Expression<String>? bodyJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (category != null) 'category': category,
      if (title != null) 'title': title,
      if (organization != null) 'organization': organization,
      if (role != null) 'role': role,
      if (location != null) 'location': location,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (description != null) 'description': description,
      if (bodyJson != null) 'body_json': bodyJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordsCompanion copyWith({
    Value<String>? id,
    Value<String>? category,
    Value<String>? title,
    Value<String?>? organization,
    Value<String?>? role,
    Value<String?>? location,
    Value<String?>? startDate,
    Value<String?>? endDate,
    Value<String>? description,
    Value<String>? bodyJson,
    Value<DateTime>? updatedAt,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return RecordsCompanion(
      id: id ?? this.id,
      category: category ?? this.category,
      title: title ?? this.title,
      organization: organization ?? this.organization,
      role: role ?? this.role,
      location: location ?? this.location,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
      bodyJson: bodyJson ?? this.bodyJson,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (organization.present) {
      map['organization'] = Variable<String>(organization.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (location.present) {
      map['location'] = Variable<String>(location.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<String>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<String>(endDate.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (bodyJson.present) {
      map['body_json'] = Variable<String>(bodyJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordsCompanion(')
          ..write('id: $id, ')
          ..write('category: $category, ')
          ..write('title: $title, ')
          ..write('organization: $organization, ')
          ..write('role: $role, ')
          ..write('location: $location, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('description: $description, ')
          ..write('bodyJson: $bodyJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AttachmentsTable extends Attachments
    with TableInfo<$AttachmentsTable, AttachmentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordIdMeta = const VerificationMeta(
    'recordId',
  );
  @override
  late final GeneratedColumn<String> recordId = GeneratedColumn<String>(
    'record_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _relPathMeta = const VerificationMeta(
    'relPath',
  );
  @override
  late final GeneratedColumn<String> relPath = GeneratedColumn<String>(
    'rel_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filenameMeta = const VerificationMeta(
    'filename',
  );
  @override
  late final GeneratedColumn<String> filename = GeneratedColumn<String>(
    'filename',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sha1Meta = const VerificationMeta('sha1');
  @override
  late final GeneratedColumn<String> sha1 = GeneratedColumn<String>(
    'sha1',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _captionMeta = const VerificationMeta(
    'caption',
  );
  @override
  late final GeneratedColumn<String> caption = GeneratedColumn<String>(
    'caption',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    recordId,
    relPath,
    filename,
    mime,
    size,
    sha1,
    caption,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<AttachmentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('record_id')) {
      context.handle(
        _recordIdMeta,
        recordId.isAcceptableOrUnknown(data['record_id']!, _recordIdMeta),
      );
    }
    if (data.containsKey('rel_path')) {
      context.handle(
        _relPathMeta,
        relPath.isAcceptableOrUnknown(data['rel_path']!, _relPathMeta),
      );
    } else if (isInserting) {
      context.missing(_relPathMeta);
    }
    if (data.containsKey('filename')) {
      context.handle(
        _filenameMeta,
        filename.isAcceptableOrUnknown(data['filename']!, _filenameMeta),
      );
    } else if (isInserting) {
      context.missing(_filenameMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(
        _mimeMeta,
        mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta),
      );
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('sha1')) {
      context.handle(
        _sha1Meta,
        sha1.isAcceptableOrUnknown(data['sha1']!, _sha1Meta),
      );
    } else if (isInserting) {
      context.missing(_sha1Meta);
    }
    if (data.containsKey('caption')) {
      context.handle(
        _captionMeta,
        caption.isAcceptableOrUnknown(data['caption']!, _captionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AttachmentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AttachmentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      recordId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_id'],
      ),
      relPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}rel_path'],
      )!,
      filename: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}filename'],
      )!,
      mime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mime'],
      ),
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      sha1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha1'],
      )!,
      caption: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}caption'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $AttachmentsTable createAlias(String alias) {
    return $AttachmentsTable(attachedDatabase, alias);
  }
}

class AttachmentRow extends DataClass implements Insertable<AttachmentRow> {
  final String id;
  final String? recordId;
  final String relPath;
  final String filename;
  final String? mime;
  final int size;
  final String sha1;
  final String? caption;
  final DateTime createdAt;
  const AttachmentRow({
    required this.id,
    this.recordId,
    required this.relPath,
    required this.filename,
    this.mime,
    required this.size,
    required this.sha1,
    this.caption,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || recordId != null) {
      map['record_id'] = Variable<String>(recordId);
    }
    map['rel_path'] = Variable<String>(relPath);
    map['filename'] = Variable<String>(filename);
    if (!nullToAbsent || mime != null) {
      map['mime'] = Variable<String>(mime);
    }
    map['size'] = Variable<int>(size);
    map['sha1'] = Variable<String>(sha1);
    if (!nullToAbsent || caption != null) {
      map['caption'] = Variable<String>(caption);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AttachmentsCompanion toCompanion(bool nullToAbsent) {
    return AttachmentsCompanion(
      id: Value(id),
      recordId: recordId == null && nullToAbsent
          ? const Value.absent()
          : Value(recordId),
      relPath: Value(relPath),
      filename: Value(filename),
      mime: mime == null && nullToAbsent ? const Value.absent() : Value(mime),
      size: Value(size),
      sha1: Value(sha1),
      caption: caption == null && nullToAbsent
          ? const Value.absent()
          : Value(caption),
      createdAt: Value(createdAt),
    );
  }

  factory AttachmentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AttachmentRow(
      id: serializer.fromJson<String>(json['id']),
      recordId: serializer.fromJson<String?>(json['recordId']),
      relPath: serializer.fromJson<String>(json['relPath']),
      filename: serializer.fromJson<String>(json['filename']),
      mime: serializer.fromJson<String?>(json['mime']),
      size: serializer.fromJson<int>(json['size']),
      sha1: serializer.fromJson<String>(json['sha1']),
      caption: serializer.fromJson<String?>(json['caption']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'recordId': serializer.toJson<String?>(recordId),
      'relPath': serializer.toJson<String>(relPath),
      'filename': serializer.toJson<String>(filename),
      'mime': serializer.toJson<String?>(mime),
      'size': serializer.toJson<int>(size),
      'sha1': serializer.toJson<String>(sha1),
      'caption': serializer.toJson<String?>(caption),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  AttachmentRow copyWith({
    String? id,
    Value<String?> recordId = const Value.absent(),
    String? relPath,
    String? filename,
    Value<String?> mime = const Value.absent(),
    int? size,
    String? sha1,
    Value<String?> caption = const Value.absent(),
    DateTime? createdAt,
  }) => AttachmentRow(
    id: id ?? this.id,
    recordId: recordId.present ? recordId.value : this.recordId,
    relPath: relPath ?? this.relPath,
    filename: filename ?? this.filename,
    mime: mime.present ? mime.value : this.mime,
    size: size ?? this.size,
    sha1: sha1 ?? this.sha1,
    caption: caption.present ? caption.value : this.caption,
    createdAt: createdAt ?? this.createdAt,
  );
  AttachmentRow copyWithCompanion(AttachmentsCompanion data) {
    return AttachmentRow(
      id: data.id.present ? data.id.value : this.id,
      recordId: data.recordId.present ? data.recordId.value : this.recordId,
      relPath: data.relPath.present ? data.relPath.value : this.relPath,
      filename: data.filename.present ? data.filename.value : this.filename,
      mime: data.mime.present ? data.mime.value : this.mime,
      size: data.size.present ? data.size.value : this.size,
      sha1: data.sha1.present ? data.sha1.value : this.sha1,
      caption: data.caption.present ? data.caption.value : this.caption,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentRow(')
          ..write('id: $id, ')
          ..write('recordId: $recordId, ')
          ..write('relPath: $relPath, ')
          ..write('filename: $filename, ')
          ..write('mime: $mime, ')
          ..write('size: $size, ')
          ..write('sha1: $sha1, ')
          ..write('caption: $caption, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    recordId,
    relPath,
    filename,
    mime,
    size,
    sha1,
    caption,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AttachmentRow &&
          other.id == this.id &&
          other.recordId == this.recordId &&
          other.relPath == this.relPath &&
          other.filename == this.filename &&
          other.mime == this.mime &&
          other.size == this.size &&
          other.sha1 == this.sha1 &&
          other.caption == this.caption &&
          other.createdAt == this.createdAt);
}

class AttachmentsCompanion extends UpdateCompanion<AttachmentRow> {
  final Value<String> id;
  final Value<String?> recordId;
  final Value<String> relPath;
  final Value<String> filename;
  final Value<String?> mime;
  final Value<int> size;
  final Value<String> sha1;
  final Value<String?> caption;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AttachmentsCompanion({
    this.id = const Value.absent(),
    this.recordId = const Value.absent(),
    this.relPath = const Value.absent(),
    this.filename = const Value.absent(),
    this.mime = const Value.absent(),
    this.size = const Value.absent(),
    this.sha1 = const Value.absent(),
    this.caption = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AttachmentsCompanion.insert({
    required String id,
    this.recordId = const Value.absent(),
    required String relPath,
    required String filename,
    this.mime = const Value.absent(),
    this.size = const Value.absent(),
    required String sha1,
    this.caption = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       relPath = Value(relPath),
       filename = Value(filename),
       sha1 = Value(sha1),
       createdAt = Value(createdAt);
  static Insertable<AttachmentRow> custom({
    Expression<String>? id,
    Expression<String>? recordId,
    Expression<String>? relPath,
    Expression<String>? filename,
    Expression<String>? mime,
    Expression<int>? size,
    Expression<String>? sha1,
    Expression<String>? caption,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (recordId != null) 'record_id': recordId,
      if (relPath != null) 'rel_path': relPath,
      if (filename != null) 'filename': filename,
      if (mime != null) 'mime': mime,
      if (size != null) 'size': size,
      if (sha1 != null) 'sha1': sha1,
      if (caption != null) 'caption': caption,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AttachmentsCompanion copyWith({
    Value<String>? id,
    Value<String?>? recordId,
    Value<String>? relPath,
    Value<String>? filename,
    Value<String?>? mime,
    Value<int>? size,
    Value<String>? sha1,
    Value<String?>? caption,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return AttachmentsCompanion(
      id: id ?? this.id,
      recordId: recordId ?? this.recordId,
      relPath: relPath ?? this.relPath,
      filename: filename ?? this.filename,
      mime: mime ?? this.mime,
      size: size ?? this.size,
      sha1: sha1 ?? this.sha1,
      caption: caption ?? this.caption,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (recordId.present) {
      map['record_id'] = Variable<String>(recordId.value);
    }
    if (relPath.present) {
      map['rel_path'] = Variable<String>(relPath.value);
    }
    if (filename.present) {
      map['filename'] = Variable<String>(filename.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (sha1.present) {
      map['sha1'] = Variable<String>(sha1.value);
    }
    if (caption.present) {
      map['caption'] = Variable<String>(caption.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AttachmentsCompanion(')
          ..write('id: $id, ')
          ..write('recordId: $recordId, ')
          ..write('relPath: $relPath, ')
          ..write('filename: $filename, ')
          ..write('mime: $mime, ')
          ..write('size: $size, ')
          ..write('sha1: $sha1, ')
          ..write('caption: $caption, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LifelineDatabase extends GeneratedDatabase {
  _$LifelineDatabase(QueryExecutor e) : super(e);
  $LifelineDatabaseManager get managers => $LifelineDatabaseManager(this);
  late final $RecordsTable records = $RecordsTable(this);
  late final $AttachmentsTable attachments = $AttachmentsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [records, attachments];
}

typedef $$RecordsTableCreateCompanionBuilder =
    RecordsCompanion Function({
      required String id,
      required String category,
      required String title,
      Value<String?> organization,
      Value<String?> role,
      Value<String?> location,
      Value<String?> startDate,
      Value<String?> endDate,
      Value<String> description,
      required String bodyJson,
      required DateTime updatedAt,
      Value<int> sortOrder,
      Value<int> rowid,
    });
typedef $$RecordsTableUpdateCompanionBuilder =
    RecordsCompanion Function({
      Value<String> id,
      Value<String> category,
      Value<String> title,
      Value<String?> organization,
      Value<String?> role,
      Value<String?> location,
      Value<String?> startDate,
      Value<String?> endDate,
      Value<String> description,
      Value<String> bodyJson,
      Value<DateTime> updatedAt,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$RecordsTableFilterComposer
    extends Composer<_$LifelineDatabase, $RecordsTable> {
  $$RecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get organization => $composableBuilder(
    column: $table.organization,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyJson => $composableBuilder(
    column: $table.bodyJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RecordsTableOrderingComposer
    extends Composer<_$LifelineDatabase, $RecordsTable> {
  $$RecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get organization => $composableBuilder(
    column: $table.organization,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get location => $composableBuilder(
    column: $table.location,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyJson => $composableBuilder(
    column: $table.bodyJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RecordsTableAnnotationComposer
    extends Composer<_$LifelineDatabase, $RecordsTable> {
  $$RecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get organization => $composableBuilder(
    column: $table.organization,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get location =>
      $composableBuilder(column: $table.location, builder: (column) => column);

  GeneratedColumn<String> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<String> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bodyJson =>
      $composableBuilder(column: $table.bodyJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$RecordsTableTableManager
    extends
        RootTableManager<
          _$LifelineDatabase,
          $RecordsTable,
          RecordRow,
          $$RecordsTableFilterComposer,
          $$RecordsTableOrderingComposer,
          $$RecordsTableAnnotationComposer,
          $$RecordsTableCreateCompanionBuilder,
          $$RecordsTableUpdateCompanionBuilder,
          (
            RecordRow,
            BaseReferences<_$LifelineDatabase, $RecordsTable, RecordRow>,
          ),
          RecordRow,
          PrefetchHooks Function()
        > {
  $$RecordsTableTableManager(_$LifelineDatabase db, $RecordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> organization = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> startDate = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String> bodyJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion(
                id: id,
                category: category,
                title: title,
                organization: organization,
                role: role,
                location: location,
                startDate: startDate,
                endDate: endDate,
                description: description,
                bodyJson: bodyJson,
                updatedAt: updatedAt,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String category,
                required String title,
                Value<String?> organization = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<String?> location = const Value.absent(),
                Value<String?> startDate = const Value.absent(),
                Value<String?> endDate = const Value.absent(),
                Value<String> description = const Value.absent(),
                required String bodyJson,
                required DateTime updatedAt,
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecordsCompanion.insert(
                id: id,
                category: category,
                title: title,
                organization: organization,
                role: role,
                location: location,
                startDate: startDate,
                endDate: endDate,
                description: description,
                bodyJson: bodyJson,
                updatedAt: updatedAt,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$LifelineDatabase,
      $RecordsTable,
      RecordRow,
      $$RecordsTableFilterComposer,
      $$RecordsTableOrderingComposer,
      $$RecordsTableAnnotationComposer,
      $$RecordsTableCreateCompanionBuilder,
      $$RecordsTableUpdateCompanionBuilder,
      (RecordRow, BaseReferences<_$LifelineDatabase, $RecordsTable, RecordRow>),
      RecordRow,
      PrefetchHooks Function()
    >;
typedef $$AttachmentsTableCreateCompanionBuilder =
    AttachmentsCompanion Function({
      required String id,
      Value<String?> recordId,
      required String relPath,
      required String filename,
      Value<String?> mime,
      Value<int> size,
      required String sha1,
      Value<String?> caption,
      required DateTime createdAt,
      Value<int> rowid,
    });
typedef $$AttachmentsTableUpdateCompanionBuilder =
    AttachmentsCompanion Function({
      Value<String> id,
      Value<String?> recordId,
      Value<String> relPath,
      Value<String> filename,
      Value<String?> mime,
      Value<int> size,
      Value<String> sha1,
      Value<String?> caption,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$AttachmentsTableFilterComposer
    extends Composer<_$LifelineDatabase, $AttachmentsTable> {
  $$AttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha1 => $composableBuilder(
    column: $table.sha1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AttachmentsTableOrderingComposer
    extends Composer<_$LifelineDatabase, $AttachmentsTable> {
  $$AttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordId => $composableBuilder(
    column: $table.recordId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relPath => $composableBuilder(
    column: $table.relPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filename => $composableBuilder(
    column: $table.filename,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mime => $composableBuilder(
    column: $table.mime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha1 => $composableBuilder(
    column: $table.sha1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get caption => $composableBuilder(
    column: $table.caption,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AttachmentsTableAnnotationComposer
    extends Composer<_$LifelineDatabase, $AttachmentsTable> {
  $$AttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get recordId =>
      $composableBuilder(column: $table.recordId, builder: (column) => column);

  GeneratedColumn<String> get relPath =>
      $composableBuilder(column: $table.relPath, builder: (column) => column);

  GeneratedColumn<String> get filename =>
      $composableBuilder(column: $table.filename, builder: (column) => column);

  GeneratedColumn<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<String> get sha1 =>
      $composableBuilder(column: $table.sha1, builder: (column) => column);

  GeneratedColumn<String> get caption =>
      $composableBuilder(column: $table.caption, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AttachmentsTableTableManager
    extends
        RootTableManager<
          _$LifelineDatabase,
          $AttachmentsTable,
          AttachmentRow,
          $$AttachmentsTableFilterComposer,
          $$AttachmentsTableOrderingComposer,
          $$AttachmentsTableAnnotationComposer,
          $$AttachmentsTableCreateCompanionBuilder,
          $$AttachmentsTableUpdateCompanionBuilder,
          (
            AttachmentRow,
            BaseReferences<
              _$LifelineDatabase,
              $AttachmentsTable,
              AttachmentRow
            >,
          ),
          AttachmentRow,
          PrefetchHooks Function()
        > {
  $$AttachmentsTableTableManager(_$LifelineDatabase db, $AttachmentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> recordId = const Value.absent(),
                Value<String> relPath = const Value.absent(),
                Value<String> filename = const Value.absent(),
                Value<String?> mime = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<String> sha1 = const Value.absent(),
                Value<String?> caption = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion(
                id: id,
                recordId: recordId,
                relPath: relPath,
                filename: filename,
                mime: mime,
                size: size,
                sha1: sha1,
                caption: caption,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> recordId = const Value.absent(),
                required String relPath,
                required String filename,
                Value<String?> mime = const Value.absent(),
                Value<int> size = const Value.absent(),
                required String sha1,
                Value<String?> caption = const Value.absent(),
                required DateTime createdAt,
                Value<int> rowid = const Value.absent(),
              }) => AttachmentsCompanion.insert(
                id: id,
                recordId: recordId,
                relPath: relPath,
                filename: filename,
                mime: mime,
                size: size,
                sha1: sha1,
                caption: caption,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$LifelineDatabase,
      $AttachmentsTable,
      AttachmentRow,
      $$AttachmentsTableFilterComposer,
      $$AttachmentsTableOrderingComposer,
      $$AttachmentsTableAnnotationComposer,
      $$AttachmentsTableCreateCompanionBuilder,
      $$AttachmentsTableUpdateCompanionBuilder,
      (
        AttachmentRow,
        BaseReferences<_$LifelineDatabase, $AttachmentsTable, AttachmentRow>,
      ),
      AttachmentRow,
      PrefetchHooks Function()
    >;

class $LifelineDatabaseManager {
  final _$LifelineDatabase _db;
  $LifelineDatabaseManager(this._db);
  $$RecordsTableTableManager get records =>
      $$RecordsTableTableManager(_db, _db.records);
  $$AttachmentsTableTableManager get attachments =>
      $$AttachmentsTableTableManager(_db, _db.attachments);
}
