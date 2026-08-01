// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AppMetaTable extends AppMeta with TableInfo<$AppMetaTable, AppMetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_meta';
  @override
  VerificationContext validateIntegrity(Insertable<AppMetaData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppMetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetaData(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppMetaTable createAlias(String alias) {
    return $AppMetaTable(attachedDatabase, alias);
  }
}

class AppMetaData extends DataClass implements Insertable<AppMetaData> {
  final String key;
  final String value;
  const AppMetaData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppMetaCompanion toCompanion(bool nullToAbsent) {
    return AppMetaCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory AppMetaData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetaData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  AppMetaData copyWith({String? key, String? value}) => AppMetaData(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  AppMetaData copyWithCompanion(AppMetaCompanion data) {
    return AppMetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetaData &&
          other.key == this.key &&
          other.value == this.value);
}

class AppMetaCompanion extends UpdateCompanion<AppMetaData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppMetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppMetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<AppMetaData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppMetaCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppMetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AccountsTable extends Accounts with TableInfo<$AccountsTable, Account> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<AccountType, String> accountType =
      GeneratedColumn<String>('account_type', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<AccountType>($AccountsTable.$converteraccountType);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _initialBalanceMeta =
      const VerificationMeta('initialBalance');
  @override
  late final GeneratedColumn<int> initialBalance = GeneratedColumn<int>(
      'initial_balance', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _archivedMeta =
      const VerificationMeta('archived');
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
      'archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        remoteId,
        accountType,
        name,
        currency,
        initialBalance,
        archived,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'accounts';
  @override
  VerificationContext validateIntegrity(Insertable<Account> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('initial_balance')) {
      context.handle(
          _initialBalanceMeta,
          initialBalance.isAcceptableOrUnknown(
              data['initial_balance']!, _initialBalanceMeta));
    }
    if (data.containsKey('archived')) {
      context.handle(_archivedMeta,
          archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Account map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Account(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      accountType: $AccountsTable.$converteraccountType.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}account_type'])!),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      initialBalance: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}initial_balance'])!,
      archived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}archived'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AccountsTable createAlias(String alias) {
    return $AccountsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AccountType, String, String> $converteraccountType =
      const EnumNameConverter<AccountType>(AccountType.values);
}

class Account extends DataClass implements Insertable<Account> {
  final int id;

  /// 跨设备实体身份（uuid v4，同步域 entity_id；本地创建时生成，合并时沿用远端值）
  final String? remoteId;
  final AccountType accountType;
  final String name;
  final String currency;
  final int initialBalance;
  final bool archived;
  final DateTime createdAt;
  const Account(
      {required this.id,
      this.remoteId,
      required this.accountType,
      required this.name,
      required this.currency,
      required this.initialBalance,
      required this.archived,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    {
      map['account_type'] = Variable<String>(
          $AccountsTable.$converteraccountType.toSql(accountType));
    }
    map['name'] = Variable<String>(name);
    map['currency'] = Variable<String>(currency);
    map['initial_balance'] = Variable<int>(initialBalance);
    map['archived'] = Variable<bool>(archived);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AccountsCompanion toCompanion(bool nullToAbsent) {
    return AccountsCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      accountType: Value(accountType),
      name: Value(name),
      currency: Value(currency),
      initialBalance: Value(initialBalance),
      archived: Value(archived),
      createdAt: Value(createdAt),
    );
  }

  factory Account.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Account(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      accountType: $AccountsTable.$converteraccountType
          .fromJson(serializer.fromJson<String>(json['accountType'])),
      name: serializer.fromJson<String>(json['name']),
      currency: serializer.fromJson<String>(json['currency']),
      initialBalance: serializer.fromJson<int>(json['initialBalance']),
      archived: serializer.fromJson<bool>(json['archived']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<String?>(remoteId),
      'accountType': serializer.toJson<String>(
          $AccountsTable.$converteraccountType.toJson(accountType)),
      'name': serializer.toJson<String>(name),
      'currency': serializer.toJson<String>(currency),
      'initialBalance': serializer.toJson<int>(initialBalance),
      'archived': serializer.toJson<bool>(archived),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Account copyWith(
          {int? id,
          Value<String?> remoteId = const Value.absent(),
          AccountType? accountType,
          String? name,
          String? currency,
          int? initialBalance,
          bool? archived,
          DateTime? createdAt}) =>
      Account(
        id: id ?? this.id,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        accountType: accountType ?? this.accountType,
        name: name ?? this.name,
        currency: currency ?? this.currency,
        initialBalance: initialBalance ?? this.initialBalance,
        archived: archived ?? this.archived,
        createdAt: createdAt ?? this.createdAt,
      );
  Account copyWithCompanion(AccountsCompanion data) {
    return Account(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      accountType:
          data.accountType.present ? data.accountType.value : this.accountType,
      name: data.name.present ? data.name.value : this.name,
      currency: data.currency.present ? data.currency.value : this.currency,
      initialBalance: data.initialBalance.present
          ? data.initialBalance.value
          : this.initialBalance,
      archived: data.archived.present ? data.archived.value : this.archived,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Account(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('accountType: $accountType, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, remoteId, accountType, name, currency,
      initialBalance, archived, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Account &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.accountType == this.accountType &&
          other.name == this.name &&
          other.currency == this.currency &&
          other.initialBalance == this.initialBalance &&
          other.archived == this.archived &&
          other.createdAt == this.createdAt);
}

class AccountsCompanion extends UpdateCompanion<Account> {
  final Value<int> id;
  final Value<String?> remoteId;
  final Value<AccountType> accountType;
  final Value<String> name;
  final Value<String> currency;
  final Value<int> initialBalance;
  final Value<bool> archived;
  final Value<DateTime> createdAt;
  const AccountsCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.accountType = const Value.absent(),
    this.name = const Value.absent(),
    this.currency = const Value.absent(),
    this.initialBalance = const Value.absent(),
    this.archived = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AccountsCompanion.insert({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    required AccountType accountType,
    required String name,
    required String currency,
    this.initialBalance = const Value.absent(),
    this.archived = const Value.absent(),
    required DateTime createdAt,
  })  : accountType = Value(accountType),
        name = Value(name),
        currency = Value(currency),
        createdAt = Value(createdAt);
  static Insertable<Account> custom({
    Expression<int>? id,
    Expression<String>? remoteId,
    Expression<String>? accountType,
    Expression<String>? name,
    Expression<String>? currency,
    Expression<int>? initialBalance,
    Expression<bool>? archived,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (accountType != null) 'account_type': accountType,
      if (name != null) 'name': name,
      if (currency != null) 'currency': currency,
      if (initialBalance != null) 'initial_balance': initialBalance,
      if (archived != null) 'archived': archived,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AccountsCompanion copyWith(
      {Value<int>? id,
      Value<String?>? remoteId,
      Value<AccountType>? accountType,
      Value<String>? name,
      Value<String>? currency,
      Value<int>? initialBalance,
      Value<bool>? archived,
      Value<DateTime>? createdAt}) {
    return AccountsCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      accountType: accountType ?? this.accountType,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      initialBalance: initialBalance ?? this.initialBalance,
      archived: archived ?? this.archived,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (accountType.present) {
      map['account_type'] = Variable<String>(
          $AccountsTable.$converteraccountType.toSql(accountType.value));
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (initialBalance.present) {
      map['initial_balance'] = Variable<int>(initialBalance.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountsCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('accountType: $accountType, ')
          ..write('name: $name, ')
          ..write('currency: $currency, ')
          ..write('initialBalance: $initialBalance, ')
          ..write('archived: $archived, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $AccountSnapshotsTable extends AccountSnapshots
    with TableInfo<$AccountSnapshotsTable, AccountSnapshot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AccountSnapshotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
      'account_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
      'date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _balanceMinorMeta =
      const VerificationMeta('balanceMinor');
  @override
  late final GeneratedColumn<int> balanceMinor = GeneratedColumn<int>(
      'balance_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, accountId, date, balanceMinor];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'account_snapshots';
  @override
  VerificationContext validateIntegrity(Insertable<AccountSnapshot> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
          _dateMeta, date.isAcceptableOrUnknown(data['date']!, _dateMeta));
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('balance_minor')) {
      context.handle(
          _balanceMinorMeta,
          balanceMinor.isAcceptableOrUnknown(
              data['balance_minor']!, _balanceMinorMeta));
    } else if (isInserting) {
      context.missing(_balanceMinorMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {accountId, date},
      ];
  @override
  AccountSnapshot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AccountSnapshot(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}account_id'])!,
      date: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date'])!,
      balanceMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}balance_minor'])!,
    );
  }

  @override
  $AccountSnapshotsTable createAlias(String alias) {
    return $AccountSnapshotsTable(attachedDatabase, alias);
  }
}

class AccountSnapshot extends DataClass implements Insertable<AccountSnapshot> {
  final int id;
  final int accountId;
  final String date;
  final int balanceMinor;
  const AccountSnapshot(
      {required this.id,
      required this.accountId,
      required this.date,
      required this.balanceMinor});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['account_id'] = Variable<int>(accountId);
    map['date'] = Variable<String>(date);
    map['balance_minor'] = Variable<int>(balanceMinor);
    return map;
  }

  AccountSnapshotsCompanion toCompanion(bool nullToAbsent) {
    return AccountSnapshotsCompanion(
      id: Value(id),
      accountId: Value(accountId),
      date: Value(date),
      balanceMinor: Value(balanceMinor),
    );
  }

  factory AccountSnapshot.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AccountSnapshot(
      id: serializer.fromJson<int>(json['id']),
      accountId: serializer.fromJson<int>(json['accountId']),
      date: serializer.fromJson<String>(json['date']),
      balanceMinor: serializer.fromJson<int>(json['balanceMinor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'accountId': serializer.toJson<int>(accountId),
      'date': serializer.toJson<String>(date),
      'balanceMinor': serializer.toJson<int>(balanceMinor),
    };
  }

  AccountSnapshot copyWith(
          {int? id, int? accountId, String? date, int? balanceMinor}) =>
      AccountSnapshot(
        id: id ?? this.id,
        accountId: accountId ?? this.accountId,
        date: date ?? this.date,
        balanceMinor: balanceMinor ?? this.balanceMinor,
      );
  AccountSnapshot copyWithCompanion(AccountSnapshotsCompanion data) {
    return AccountSnapshot(
      id: data.id.present ? data.id.value : this.id,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      date: data.date.present ? data.date.value : this.date,
      balanceMinor: data.balanceMinor.present
          ? data.balanceMinor.value
          : this.balanceMinor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AccountSnapshot(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('date: $date, ')
          ..write('balanceMinor: $balanceMinor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, accountId, date, balanceMinor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AccountSnapshot &&
          other.id == this.id &&
          other.accountId == this.accountId &&
          other.date == this.date &&
          other.balanceMinor == this.balanceMinor);
}

class AccountSnapshotsCompanion extends UpdateCompanion<AccountSnapshot> {
  final Value<int> id;
  final Value<int> accountId;
  final Value<String> date;
  final Value<int> balanceMinor;
  const AccountSnapshotsCompanion({
    this.id = const Value.absent(),
    this.accountId = const Value.absent(),
    this.date = const Value.absent(),
    this.balanceMinor = const Value.absent(),
  });
  AccountSnapshotsCompanion.insert({
    this.id = const Value.absent(),
    required int accountId,
    required String date,
    required int balanceMinor,
  })  : accountId = Value(accountId),
        date = Value(date),
        balanceMinor = Value(balanceMinor);
  static Insertable<AccountSnapshot> custom({
    Expression<int>? id,
    Expression<int>? accountId,
    Expression<String>? date,
    Expression<int>? balanceMinor,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (accountId != null) 'account_id': accountId,
      if (date != null) 'date': date,
      if (balanceMinor != null) 'balance_minor': balanceMinor,
    });
  }

  AccountSnapshotsCompanion copyWith(
      {Value<int>? id,
      Value<int>? accountId,
      Value<String>? date,
      Value<int>? balanceMinor}) {
    return AccountSnapshotsCompanion(
      id: id ?? this.id,
      accountId: accountId ?? this.accountId,
      date: date ?? this.date,
      balanceMinor: balanceMinor ?? this.balanceMinor,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (balanceMinor.present) {
      map['balance_minor'] = Variable<int>(balanceMinor.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AccountSnapshotsCompanion(')
          ..write('id: $id, ')
          ..write('accountId: $accountId, ')
          ..write('date: $date, ')
          ..write('balanceMinor: $balanceMinor')
          ..write(')'))
        .toString();
  }
}

class $CategoriesTable extends Categories
    with TableInfo<$CategoriesTable, Category> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CategoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<int> parentId = GeneratedColumn<int>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
      'icon', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
      'color', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  late final GeneratedColumnWithTypeConverter<CategoryKind, String> kind =
      GeneratedColumn<String>('kind', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<CategoryKind>($CategoriesTable.$converterkind);
  static const VerificationMeta _isSystemMeta =
      const VerificationMeta('isSystem');
  @override
  late final GeneratedColumn<bool> isSystem = GeneratedColumn<bool>(
      'is_system', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_system" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sortOrderMeta =
      const VerificationMeta('sortOrder');
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
      'sort_order', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        remoteId,
        parentId,
        name,
        icon,
        color,
        kind,
        isSystem,
        sortOrder,
        deletedAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'categories';
  @override
  VerificationContext validateIntegrity(Insertable<Category> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
          _iconMeta, icon.isAcceptableOrUnknown(data['icon']!, _iconMeta));
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    } else if (isInserting) {
      context.missing(_colorMeta);
    }
    if (data.containsKey('is_system')) {
      context.handle(_isSystemMeta,
          isSystem.isAcceptableOrUnknown(data['is_system']!, _isSystemMeta));
    }
    if (data.containsKey('sort_order')) {
      context.handle(_sortOrderMeta,
          sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Category map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Category(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}parent_id']),
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      icon: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}icon'])!,
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color'])!,
      kind: $CategoriesTable.$converterkind.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!),
      isSystem: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_system'])!,
      sortOrder: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}sort_order'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $CategoriesTable createAlias(String alias) {
    return $CategoriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<CategoryKind, String, String> $converterkind =
      const EnumNameConverter<CategoryKind>(CategoryKind.values);
}

class Category extends DataClass implements Insertable<Category> {
  final int id;

  /// 跨设备实体身份（uuid v4，同步域 entity_id）
  final String? remoteId;
  final int? parentId;
  final String name;
  final String icon;
  final int color;
  final CategoryKind kind;
  final bool isSystem;
  final int sortOrder;
  final DateTime? deletedAt;
  final DateTime updatedAt;
  const Category(
      {required this.id,
      this.remoteId,
      this.parentId,
      required this.name,
      required this.icon,
      required this.color,
      required this.kind,
      required this.isSystem,
      required this.sortOrder,
      this.deletedAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<int>(parentId);
    }
    map['name'] = Variable<String>(name);
    map['icon'] = Variable<String>(icon);
    map['color'] = Variable<int>(color);
    {
      map['kind'] =
          Variable<String>($CategoriesTable.$converterkind.toSql(kind));
    }
    map['is_system'] = Variable<bool>(isSystem);
    map['sort_order'] = Variable<int>(sortOrder);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CategoriesCompanion toCompanion(bool nullToAbsent) {
    return CategoriesCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      name: Value(name),
      icon: Value(icon),
      color: Value(color),
      kind: Value(kind),
      isSystem: Value(isSystem),
      sortOrder: Value(sortOrder),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Category.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Category(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      parentId: serializer.fromJson<int?>(json['parentId']),
      name: serializer.fromJson<String>(json['name']),
      icon: serializer.fromJson<String>(json['icon']),
      color: serializer.fromJson<int>(json['color']),
      kind: $CategoriesTable.$converterkind
          .fromJson(serializer.fromJson<String>(json['kind'])),
      isSystem: serializer.fromJson<bool>(json['isSystem']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<String?>(remoteId),
      'parentId': serializer.toJson<int?>(parentId),
      'name': serializer.toJson<String>(name),
      'icon': serializer.toJson<String>(icon),
      'color': serializer.toJson<int>(color),
      'kind': serializer
          .toJson<String>($CategoriesTable.$converterkind.toJson(kind)),
      'isSystem': serializer.toJson<bool>(isSystem),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Category copyWith(
          {int? id,
          Value<String?> remoteId = const Value.absent(),
          Value<int?> parentId = const Value.absent(),
          String? name,
          String? icon,
          int? color,
          CategoryKind? kind,
          bool? isSystem,
          int? sortOrder,
          Value<DateTime?> deletedAt = const Value.absent(),
          DateTime? updatedAt}) =>
      Category(
        id: id ?? this.id,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        parentId: parentId.present ? parentId.value : this.parentId,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        kind: kind ?? this.kind,
        isSystem: isSystem ?? this.isSystem,
        sortOrder: sortOrder ?? this.sortOrder,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Category copyWithCompanion(CategoriesCompanion data) {
    return Category(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      name: data.name.present ? data.name.value : this.name,
      icon: data.icon.present ? data.icon.value : this.icon,
      color: data.color.present ? data.color.value : this.color,
      kind: data.kind.present ? data.kind.value : this.kind,
      isSystem: data.isSystem.present ? data.isSystem.value : this.isSystem,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Category(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('kind: $kind, ')
          ..write('isSystem: $isSystem, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, remoteId, parentId, name, icon, color,
      kind, isSystem, sortOrder, deletedAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Category &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.parentId == this.parentId &&
          other.name == this.name &&
          other.icon == this.icon &&
          other.color == this.color &&
          other.kind == this.kind &&
          other.isSystem == this.isSystem &&
          other.sortOrder == this.sortOrder &&
          other.deletedAt == this.deletedAt &&
          other.updatedAt == this.updatedAt);
}

class CategoriesCompanion extends UpdateCompanion<Category> {
  final Value<int> id;
  final Value<String?> remoteId;
  final Value<int?> parentId;
  final Value<String> name;
  final Value<String> icon;
  final Value<int> color;
  final Value<CategoryKind> kind;
  final Value<bool> isSystem;
  final Value<int> sortOrder;
  final Value<DateTime?> deletedAt;
  final Value<DateTime> updatedAt;
  const CategoriesCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.parentId = const Value.absent(),
    this.name = const Value.absent(),
    this.icon = const Value.absent(),
    this.color = const Value.absent(),
    this.kind = const Value.absent(),
    this.isSystem = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  CategoriesCompanion.insert({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.parentId = const Value.absent(),
    required String name,
    required String icon,
    required int color,
    required CategoryKind kind,
    this.isSystem = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required DateTime updatedAt,
  })  : name = Value(name),
        icon = Value(icon),
        color = Value(color),
        kind = Value(kind),
        updatedAt = Value(updatedAt);
  static Insertable<Category> custom({
    Expression<int>? id,
    Expression<String>? remoteId,
    Expression<int>? parentId,
    Expression<String>? name,
    Expression<String>? icon,
    Expression<int>? color,
    Expression<String>? kind,
    Expression<bool>? isSystem,
    Expression<int>? sortOrder,
    Expression<DateTime>? deletedAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (parentId != null) 'parent_id': parentId,
      if (name != null) 'name': name,
      if (icon != null) 'icon': icon,
      if (color != null) 'color': color,
      if (kind != null) 'kind': kind,
      if (isSystem != null) 'is_system': isSystem,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  CategoriesCompanion copyWith(
      {Value<int>? id,
      Value<String?>? remoteId,
      Value<int?>? parentId,
      Value<String>? name,
      Value<String>? icon,
      Value<int>? color,
      Value<CategoryKind>? kind,
      Value<bool>? isSystem,
      Value<int>? sortOrder,
      Value<DateTime?>? deletedAt,
      Value<DateTime>? updatedAt}) {
    return CategoriesCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      parentId: parentId ?? this.parentId,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      kind: kind ?? this.kind,
      isSystem: isSystem ?? this.isSystem,
      sortOrder: sortOrder ?? this.sortOrder,
      deletedAt: deletedAt ?? this.deletedAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<int>(parentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (kind.present) {
      map['kind'] =
          Variable<String>($CategoriesTable.$converterkind.toSql(kind.value));
    }
    if (isSystem.present) {
      map['is_system'] = Variable<bool>(isSystem.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CategoriesCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('parentId: $parentId, ')
          ..write('name: $name, ')
          ..write('icon: $icon, ')
          ..write('color: $color, ')
          ..write('kind: $kind, ')
          ..write('isSystem: $isSystem, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TransactionsTable extends Transactions
    with TableInfo<$TransactionsTable, Transaction> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TransactionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _accountIdMeta =
      const VerificationMeta('accountId');
  @override
  late final GeneratedColumn<int> accountId = GeneratedColumn<int>(
      'account_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<TransactionType, String> type =
      GeneratedColumn<String>('type', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<TransactionType>($TransactionsTable.$convertertype);
  static const VerificationMeta _amountMinorMeta =
      const VerificationMeta('amountMinor');
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
      'amount_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _currencyMeta =
      const VerificationMeta('currency');
  @override
  late final GeneratedColumn<String> currency = GeneratedColumn<String>(
      'currency', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rateSnapshotMeta =
      const VerificationMeta('rateSnapshot');
  @override
  late final GeneratedColumn<int> rateSnapshot = GeneratedColumn<int>(
      'rate_snapshot', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(kRateScale));
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _occurredAtMeta =
      const VerificationMeta('occurredAt');
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
      'occurred_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _transferIdMeta =
      const VerificationMeta('transferId');
  @override
  late final GeneratedColumn<int> transferId = GeneratedColumn<int>(
      'transfer_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _autoGeneratedMeta =
      const VerificationMeta('autoGenerated');
  @override
  late final GeneratedColumn<bool> autoGenerated = GeneratedColumn<bool>(
      'auto_generated', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("auto_generated" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        remoteId,
        accountId,
        categoryId,
        type,
        amountMinor,
        currency,
        rateSnapshot,
        note,
        occurredAt,
        transferId,
        autoGenerated,
        updatedAt,
        deletedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'transactions';
  @override
  VerificationContext validateIntegrity(Insertable<Transaction> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('account_id')) {
      context.handle(_accountIdMeta,
          accountId.isAcceptableOrUnknown(data['account_id']!, _accountIdMeta));
    } else if (isInserting) {
      context.missing(_accountIdMeta);
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
          _amountMinorMeta,
          amountMinor.isAcceptableOrUnknown(
              data['amount_minor']!, _amountMinorMeta));
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('currency')) {
      context.handle(_currencyMeta,
          currency.isAcceptableOrUnknown(data['currency']!, _currencyMeta));
    } else if (isInserting) {
      context.missing(_currencyMeta);
    }
    if (data.containsKey('rate_snapshot')) {
      context.handle(
          _rateSnapshotMeta,
          rateSnapshot.isAcceptableOrUnknown(
              data['rate_snapshot']!, _rateSnapshotMeta));
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
          _occurredAtMeta,
          occurredAt.isAcceptableOrUnknown(
              data['occurred_at']!, _occurredAtMeta));
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('transfer_id')) {
      context.handle(
          _transferIdMeta,
          transferId.isAcceptableOrUnknown(
              data['transfer_id']!, _transferIdMeta));
    }
    if (data.containsKey('auto_generated')) {
      context.handle(
          _autoGeneratedMeta,
          autoGenerated.isAcceptableOrUnknown(
              data['auto_generated']!, _autoGeneratedMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Transaction map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Transaction(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      accountId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}account_id'])!,
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id']),
      type: $TransactionsTable.$convertertype.fromSql(attachedDatabase
          .typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!),
      amountMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_minor'])!,
      currency: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}currency'])!,
      rateSnapshot: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}rate_snapshot'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      occurredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}occurred_at'])!,
      transferId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}transfer_id']),
      autoGenerated: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}auto_generated'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}deleted_at']),
    );
  }

  @override
  $TransactionsTable createAlias(String alias) {
    return $TransactionsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TransactionType, String, String> $convertertype =
      const EnumNameConverter<TransactionType>(TransactionType.values);
}

class Transaction extends DataClass implements Insertable<Transaction> {
  final int id;

  /// 跨设备实体身份（uuid v4，同步域 entity_id）
  final String? remoteId;
  final int accountId;
  final int? categoryId;
  final TransactionType type;
  final int amountMinor;
  final String currency;
  final int rateSnapshot;
  final String? note;
  final DateTime occurredAt;
  final int? transferId;
  final bool autoGenerated;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const Transaction(
      {required this.id,
      this.remoteId,
      required this.accountId,
      this.categoryId,
      required this.type,
      required this.amountMinor,
      required this.currency,
      required this.rateSnapshot,
      this.note,
      required this.occurredAt,
      this.transferId,
      required this.autoGenerated,
      required this.updatedAt,
      this.deletedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['account_id'] = Variable<int>(accountId);
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    {
      map['type'] =
          Variable<String>($TransactionsTable.$convertertype.toSql(type));
    }
    map['amount_minor'] = Variable<int>(amountMinor);
    map['currency'] = Variable<String>(currency);
    map['rate_snapshot'] = Variable<int>(rateSnapshot);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    if (!nullToAbsent || transferId != null) {
      map['transfer_id'] = Variable<int>(transferId);
    }
    map['auto_generated'] = Variable<bool>(autoGenerated);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  TransactionsCompanion toCompanion(bool nullToAbsent) {
    return TransactionsCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      accountId: Value(accountId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      type: Value(type),
      amountMinor: Value(amountMinor),
      currency: Value(currency),
      rateSnapshot: Value(rateSnapshot),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      occurredAt: Value(occurredAt),
      transferId: transferId == null && nullToAbsent
          ? const Value.absent()
          : Value(transferId),
      autoGenerated: Value(autoGenerated),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Transaction(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      accountId: serializer.fromJson<int>(json['accountId']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      type: $TransactionsTable.$convertertype
          .fromJson(serializer.fromJson<String>(json['type'])),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      currency: serializer.fromJson<String>(json['currency']),
      rateSnapshot: serializer.fromJson<int>(json['rateSnapshot']),
      note: serializer.fromJson<String?>(json['note']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      transferId: serializer.fromJson<int?>(json['transferId']),
      autoGenerated: serializer.fromJson<bool>(json['autoGenerated']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<String?>(remoteId),
      'accountId': serializer.toJson<int>(accountId),
      'categoryId': serializer.toJson<int?>(categoryId),
      'type': serializer
          .toJson<String>($TransactionsTable.$convertertype.toJson(type)),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'currency': serializer.toJson<String>(currency),
      'rateSnapshot': serializer.toJson<int>(rateSnapshot),
      'note': serializer.toJson<String?>(note),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'transferId': serializer.toJson<int?>(transferId),
      'autoGenerated': serializer.toJson<bool>(autoGenerated),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  Transaction copyWith(
          {int? id,
          Value<String?> remoteId = const Value.absent(),
          int? accountId,
          Value<int?> categoryId = const Value.absent(),
          TransactionType? type,
          int? amountMinor,
          String? currency,
          int? rateSnapshot,
          Value<String?> note = const Value.absent(),
          DateTime? occurredAt,
          Value<int?> transferId = const Value.absent(),
          bool? autoGenerated,
          DateTime? updatedAt,
          Value<DateTime?> deletedAt = const Value.absent()}) =>
      Transaction(
        id: id ?? this.id,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        accountId: accountId ?? this.accountId,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        type: type ?? this.type,
        amountMinor: amountMinor ?? this.amountMinor,
        currency: currency ?? this.currency,
        rateSnapshot: rateSnapshot ?? this.rateSnapshot,
        note: note.present ? note.value : this.note,
        occurredAt: occurredAt ?? this.occurredAt,
        transferId: transferId.present ? transferId.value : this.transferId,
        autoGenerated: autoGenerated ?? this.autoGenerated,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
      );
  Transaction copyWithCompanion(TransactionsCompanion data) {
    return Transaction(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      accountId: data.accountId.present ? data.accountId.value : this.accountId,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      type: data.type.present ? data.type.value : this.type,
      amountMinor:
          data.amountMinor.present ? data.amountMinor.value : this.amountMinor,
      currency: data.currency.present ? data.currency.value : this.currency,
      rateSnapshot: data.rateSnapshot.present
          ? data.rateSnapshot.value
          : this.rateSnapshot,
      note: data.note.present ? data.note.value : this.note,
      occurredAt:
          data.occurredAt.present ? data.occurredAt.value : this.occurredAt,
      transferId:
          data.transferId.present ? data.transferId.value : this.transferId,
      autoGenerated: data.autoGenerated.present
          ? data.autoGenerated.value
          : this.autoGenerated,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Transaction(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('type: $type, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('rateSnapshot: $rateSnapshot, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('transferId: $transferId, ')
          ..write('autoGenerated: $autoGenerated, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      remoteId,
      accountId,
      categoryId,
      type,
      amountMinor,
      currency,
      rateSnapshot,
      note,
      occurredAt,
      transferId,
      autoGenerated,
      updatedAt,
      deletedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Transaction &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.accountId == this.accountId &&
          other.categoryId == this.categoryId &&
          other.type == this.type &&
          other.amountMinor == this.amountMinor &&
          other.currency == this.currency &&
          other.rateSnapshot == this.rateSnapshot &&
          other.note == this.note &&
          other.occurredAt == this.occurredAt &&
          other.transferId == this.transferId &&
          other.autoGenerated == this.autoGenerated &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class TransactionsCompanion extends UpdateCompanion<Transaction> {
  final Value<int> id;
  final Value<String?> remoteId;
  final Value<int> accountId;
  final Value<int?> categoryId;
  final Value<TransactionType> type;
  final Value<int> amountMinor;
  final Value<String> currency;
  final Value<int> rateSnapshot;
  final Value<String?> note;
  final Value<DateTime> occurredAt;
  final Value<int?> transferId;
  final Value<bool> autoGenerated;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  const TransactionsCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.accountId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.type = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.currency = const Value.absent(),
    this.rateSnapshot = const Value.absent(),
    this.note = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.transferId = const Value.absent(),
    this.autoGenerated = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  TransactionsCompanion.insert({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    required int accountId,
    this.categoryId = const Value.absent(),
    required TransactionType type,
    required int amountMinor,
    required String currency,
    this.rateSnapshot = const Value.absent(),
    this.note = const Value.absent(),
    required DateTime occurredAt,
    this.transferId = const Value.absent(),
    this.autoGenerated = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
  })  : accountId = Value(accountId),
        type = Value(type),
        amountMinor = Value(amountMinor),
        currency = Value(currency),
        occurredAt = Value(occurredAt),
        updatedAt = Value(updatedAt);
  static Insertable<Transaction> custom({
    Expression<int>? id,
    Expression<String>? remoteId,
    Expression<int>? accountId,
    Expression<int>? categoryId,
    Expression<String>? type,
    Expression<int>? amountMinor,
    Expression<String>? currency,
    Expression<int>? rateSnapshot,
    Expression<String>? note,
    Expression<DateTime>? occurredAt,
    Expression<int>? transferId,
    Expression<bool>? autoGenerated,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (accountId != null) 'account_id': accountId,
      if (categoryId != null) 'category_id': categoryId,
      if (type != null) 'type': type,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (currency != null) 'currency': currency,
      if (rateSnapshot != null) 'rate_snapshot': rateSnapshot,
      if (note != null) 'note': note,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (transferId != null) 'transfer_id': transferId,
      if (autoGenerated != null) 'auto_generated': autoGenerated,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  TransactionsCompanion copyWith(
      {Value<int>? id,
      Value<String?>? remoteId,
      Value<int>? accountId,
      Value<int?>? categoryId,
      Value<TransactionType>? type,
      Value<int>? amountMinor,
      Value<String>? currency,
      Value<int>? rateSnapshot,
      Value<String?>? note,
      Value<DateTime>? occurredAt,
      Value<int?>? transferId,
      Value<bool>? autoGenerated,
      Value<DateTime>? updatedAt,
      Value<DateTime?>? deletedAt}) {
    return TransactionsCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      rateSnapshot: rateSnapshot ?? this.rateSnapshot,
      note: note ?? this.note,
      occurredAt: occurredAt ?? this.occurredAt,
      transferId: transferId ?? this.transferId,
      autoGenerated: autoGenerated ?? this.autoGenerated,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (accountId.present) {
      map['account_id'] = Variable<int>(accountId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (type.present) {
      map['type'] =
          Variable<String>($TransactionsTable.$convertertype.toSql(type.value));
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (currency.present) {
      map['currency'] = Variable<String>(currency.value);
    }
    if (rateSnapshot.present) {
      map['rate_snapshot'] = Variable<int>(rateSnapshot.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (transferId.present) {
      map['transfer_id'] = Variable<int>(transferId.value);
    }
    if (autoGenerated.present) {
      map['auto_generated'] = Variable<bool>(autoGenerated.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TransactionsCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('accountId: $accountId, ')
          ..write('categoryId: $categoryId, ')
          ..write('type: $type, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('currency: $currency, ')
          ..write('rateSnapshot: $rateSnapshot, ')
          ..write('note: $note, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('transferId: $transferId, ')
          ..write('autoGenerated: $autoGenerated, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $BudgetsTable extends Budgets with TableInfo<$BudgetsTable, Budget> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BudgetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _categoryIdMeta =
      const VerificationMeta('categoryId');
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
      'category_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _periodMeta = const VerificationMeta('period');
  @override
  late final GeneratedColumn<String> period = GeneratedColumn<String>(
      'period', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _amountMinorMeta =
      const VerificationMeta('amountMinor');
  @override
  late final GeneratedColumn<int> amountMinor = GeneratedColumn<int>(
      'amount_minor', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _thresholdMeta =
      const VerificationMeta('threshold');
  @override
  late final GeneratedColumn<int> threshold = GeneratedColumn<int>(
      'threshold', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(80));
  @override
  List<GeneratedColumn> get $columns =>
      [id, remoteId, categoryId, period, amountMinor, threshold];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'budgets';
  @override
  VerificationContext validateIntegrity(Insertable<Budget> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('category_id')) {
      context.handle(
          _categoryIdMeta,
          categoryId.isAcceptableOrUnknown(
              data['category_id']!, _categoryIdMeta));
    }
    if (data.containsKey('period')) {
      context.handle(_periodMeta,
          period.isAcceptableOrUnknown(data['period']!, _periodMeta));
    } else if (isInserting) {
      context.missing(_periodMeta);
    }
    if (data.containsKey('amount_minor')) {
      context.handle(
          _amountMinorMeta,
          amountMinor.isAcceptableOrUnknown(
              data['amount_minor']!, _amountMinorMeta));
    } else if (isInserting) {
      context.missing(_amountMinorMeta);
    }
    if (data.containsKey('threshold')) {
      context.handle(_thresholdMeta,
          threshold.isAcceptableOrUnknown(data['threshold']!, _thresholdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Budget map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Budget(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      categoryId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}category_id']),
      period: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}period'])!,
      amountMinor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}amount_minor'])!,
      threshold: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}threshold'])!,
    );
  }

  @override
  $BudgetsTable createAlias(String alias) {
    return $BudgetsTable(attachedDatabase, alias);
  }
}

class Budget extends DataClass implements Insertable<Budget> {
  final int id;

  /// 跨设备实体身份（uuid v4，同步域 entity_id）
  final String? remoteId;
  final int? categoryId;
  final String period;
  final int amountMinor;
  final int threshold;
  const Budget(
      {required this.id,
      this.remoteId,
      this.categoryId,
      required this.period,
      required this.amountMinor,
      required this.threshold});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    if (!nullToAbsent || categoryId != null) {
      map['category_id'] = Variable<int>(categoryId);
    }
    map['period'] = Variable<String>(period);
    map['amount_minor'] = Variable<int>(amountMinor);
    map['threshold'] = Variable<int>(threshold);
    return map;
  }

  BudgetsCompanion toCompanion(bool nullToAbsent) {
    return BudgetsCompanion(
      id: Value(id),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      categoryId: categoryId == null && nullToAbsent
          ? const Value.absent()
          : Value(categoryId),
      period: Value(period),
      amountMinor: Value(amountMinor),
      threshold: Value(threshold),
    );
  }

  factory Budget.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Budget(
      id: serializer.fromJson<int>(json['id']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      categoryId: serializer.fromJson<int?>(json['categoryId']),
      period: serializer.fromJson<String>(json['period']),
      amountMinor: serializer.fromJson<int>(json['amountMinor']),
      threshold: serializer.fromJson<int>(json['threshold']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'remoteId': serializer.toJson<String?>(remoteId),
      'categoryId': serializer.toJson<int?>(categoryId),
      'period': serializer.toJson<String>(period),
      'amountMinor': serializer.toJson<int>(amountMinor),
      'threshold': serializer.toJson<int>(threshold),
    };
  }

  Budget copyWith(
          {int? id,
          Value<String?> remoteId = const Value.absent(),
          Value<int?> categoryId = const Value.absent(),
          String? period,
          int? amountMinor,
          int? threshold}) =>
      Budget(
        id: id ?? this.id,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        categoryId: categoryId.present ? categoryId.value : this.categoryId,
        period: period ?? this.period,
        amountMinor: amountMinor ?? this.amountMinor,
        threshold: threshold ?? this.threshold,
      );
  Budget copyWithCompanion(BudgetsCompanion data) {
    return Budget(
      id: data.id.present ? data.id.value : this.id,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      categoryId:
          data.categoryId.present ? data.categoryId.value : this.categoryId,
      period: data.period.present ? data.period.value : this.period,
      amountMinor:
          data.amountMinor.present ? data.amountMinor.value : this.amountMinor,
      threshold: data.threshold.present ? data.threshold.value : this.threshold,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Budget(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('categoryId: $categoryId, ')
          ..write('period: $period, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('threshold: $threshold')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, remoteId, categoryId, period, amountMinor, threshold);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Budget &&
          other.id == this.id &&
          other.remoteId == this.remoteId &&
          other.categoryId == this.categoryId &&
          other.period == this.period &&
          other.amountMinor == this.amountMinor &&
          other.threshold == this.threshold);
}

class BudgetsCompanion extends UpdateCompanion<Budget> {
  final Value<int> id;
  final Value<String?> remoteId;
  final Value<int?> categoryId;
  final Value<String> period;
  final Value<int> amountMinor;
  final Value<int> threshold;
  const BudgetsCompanion({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.period = const Value.absent(),
    this.amountMinor = const Value.absent(),
    this.threshold = const Value.absent(),
  });
  BudgetsCompanion.insert({
    this.id = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.categoryId = const Value.absent(),
    required String period,
    required int amountMinor,
    this.threshold = const Value.absent(),
  })  : period = Value(period),
        amountMinor = Value(amountMinor);
  static Insertable<Budget> custom({
    Expression<int>? id,
    Expression<String>? remoteId,
    Expression<int>? categoryId,
    Expression<String>? period,
    Expression<int>? amountMinor,
    Expression<int>? threshold,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (remoteId != null) 'remote_id': remoteId,
      if (categoryId != null) 'category_id': categoryId,
      if (period != null) 'period': period,
      if (amountMinor != null) 'amount_minor': amountMinor,
      if (threshold != null) 'threshold': threshold,
    });
  }

  BudgetsCompanion copyWith(
      {Value<int>? id,
      Value<String?>? remoteId,
      Value<int?>? categoryId,
      Value<String>? period,
      Value<int>? amountMinor,
      Value<int>? threshold}) {
    return BudgetsCompanion(
      id: id ?? this.id,
      remoteId: remoteId ?? this.remoteId,
      categoryId: categoryId ?? this.categoryId,
      period: period ?? this.period,
      amountMinor: amountMinor ?? this.amountMinor,
      threshold: threshold ?? this.threshold,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (period.present) {
      map['period'] = Variable<String>(period.value);
    }
    if (amountMinor.present) {
      map['amount_minor'] = Variable<int>(amountMinor.value);
    }
    if (threshold.present) {
      map['threshold'] = Variable<int>(threshold.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BudgetsCompanion(')
          ..write('id: $id, ')
          ..write('remoteId: $remoteId, ')
          ..write('categoryId: $categoryId, ')
          ..write('period: $period, ')
          ..write('amountMinor: $amountMinor, ')
          ..write('threshold: $threshold')
          ..write(')'))
        .toString();
  }
}

class $SyncOpsTable extends SyncOps with TableInfo<$SyncOpsTable, SyncOp> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _entityMeta = const VerificationMeta('entity');
  @override
  late final GeneratedColumn<String> entity = GeneratedColumn<String>(
      'entity', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<int> entityId = GeneratedColumn<int>(
      'entity_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _remoteIdMeta =
      const VerificationMeta('remoteId');
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
      'remote_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  late final GeneratedColumnWithTypeConverter<SyncOpCode, String> op =
      GeneratedColumn<String>('op', aliasedName, false,
              type: DriftSqlType.string, requiredDuringInsert: true)
          .withConverter<SyncOpCode>($SyncOpsTable.$converterop);
  static const VerificationMeta _payloadMeta =
      const VerificationMeta('payload');
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
      'payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lamportMeta =
      const VerificationMeta('lamport');
  @override
  late final GeneratedColumn<int> lamport = GeneratedColumn<int>(
      'lamport', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _clientIdMeta =
      const VerificationMeta('clientId');
  @override
  late final GeneratedColumn<String> clientId = GeneratedColumn<String>(
      'client_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pushedMeta = const VerificationMeta('pushed');
  @override
  late final GeneratedColumn<bool> pushed = GeneratedColumn<bool>(
      'pushed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("pushed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        entity,
        entityId,
        remoteId,
        op,
        payload,
        lamport,
        clientId,
        pushed,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_ops';
  @override
  VerificationContext validateIntegrity(Insertable<SyncOp> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('entity')) {
      context.handle(_entityMeta,
          entity.isAcceptableOrUnknown(data['entity']!, _entityMeta));
    } else if (isInserting) {
      context.missing(_entityMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(_remoteIdMeta,
          remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta));
    }
    if (data.containsKey('payload')) {
      context.handle(_payloadMeta,
          payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta));
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('lamport')) {
      context.handle(_lamportMeta,
          lamport.isAcceptableOrUnknown(data['lamport']!, _lamportMeta));
    } else if (isInserting) {
      context.missing(_lamportMeta);
    }
    if (data.containsKey('client_id')) {
      context.handle(_clientIdMeta,
          clientId.isAcceptableOrUnknown(data['client_id']!, _clientIdMeta));
    } else if (isInserting) {
      context.missing(_clientIdMeta);
    }
    if (data.containsKey('pushed')) {
      context.handle(_pushedMeta,
          pushed.isAcceptableOrUnknown(data['pushed']!, _pushedMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncOp map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOp(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      entity: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity'])!,
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}entity_id'])!,
      remoteId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}remote_id']),
      op: $SyncOpsTable.$converterop.fromSql(attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}op'])!),
      payload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}payload'])!,
      lamport: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lamport'])!,
      clientId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}client_id'])!,
      pushed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pushed'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SyncOpsTable createAlias(String alias) {
    return $SyncOpsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SyncOpCode, String, String> $converterop =
      const EnumNameConverter<SyncOpCode>(SyncOpCode.values);
}

class SyncOp extends DataClass implements Insertable<SyncOp> {
  final int id;
  final String entity;
  final int entityId;

  /// 实体跨设备身份（uuid v4），即 OpenAPI entity_id（本地实体 remote_id 列）。
  /// 可空：v3 迁移前遗留的旧 op 无远端身份，引擎跳过。
  final String? remoteId;
  final SyncOpCode op;
  final String payload;
  final int lamport;
  final String clientId;
  final bool pushed;
  final DateTime createdAt;
  const SyncOp(
      {required this.id,
      required this.entity,
      required this.entityId,
      this.remoteId,
      required this.op,
      required this.payload,
      required this.lamport,
      required this.clientId,
      required this.pushed,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['entity'] = Variable<String>(entity);
    map['entity_id'] = Variable<int>(entityId);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    {
      map['op'] = Variable<String>($SyncOpsTable.$converterop.toSql(op));
    }
    map['payload'] = Variable<String>(payload);
    map['lamport'] = Variable<int>(lamport);
    map['client_id'] = Variable<String>(clientId);
    map['pushed'] = Variable<bool>(pushed);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SyncOpsCompanion toCompanion(bool nullToAbsent) {
    return SyncOpsCompanion(
      id: Value(id),
      entity: Value(entity),
      entityId: Value(entityId),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      op: Value(op),
      payload: Value(payload),
      lamport: Value(lamport),
      clientId: Value(clientId),
      pushed: Value(pushed),
      createdAt: Value(createdAt),
    );
  }

  factory SyncOp.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOp(
      id: serializer.fromJson<int>(json['id']),
      entity: serializer.fromJson<String>(json['entity']),
      entityId: serializer.fromJson<int>(json['entityId']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      op: $SyncOpsTable.$converterop
          .fromJson(serializer.fromJson<String>(json['op'])),
      payload: serializer.fromJson<String>(json['payload']),
      lamport: serializer.fromJson<int>(json['lamport']),
      clientId: serializer.fromJson<String>(json['clientId']),
      pushed: serializer.fromJson<bool>(json['pushed']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'entity': serializer.toJson<String>(entity),
      'entityId': serializer.toJson<int>(entityId),
      'remoteId': serializer.toJson<String?>(remoteId),
      'op': serializer.toJson<String>($SyncOpsTable.$converterop.toJson(op)),
      'payload': serializer.toJson<String>(payload),
      'lamport': serializer.toJson<int>(lamport),
      'clientId': serializer.toJson<String>(clientId),
      'pushed': serializer.toJson<bool>(pushed),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SyncOp copyWith(
          {int? id,
          String? entity,
          int? entityId,
          Value<String?> remoteId = const Value.absent(),
          SyncOpCode? op,
          String? payload,
          int? lamport,
          String? clientId,
          bool? pushed,
          DateTime? createdAt}) =>
      SyncOp(
        id: id ?? this.id,
        entity: entity ?? this.entity,
        entityId: entityId ?? this.entityId,
        remoteId: remoteId.present ? remoteId.value : this.remoteId,
        op: op ?? this.op,
        payload: payload ?? this.payload,
        lamport: lamport ?? this.lamport,
        clientId: clientId ?? this.clientId,
        pushed: pushed ?? this.pushed,
        createdAt: createdAt ?? this.createdAt,
      );
  SyncOp copyWithCompanion(SyncOpsCompanion data) {
    return SyncOp(
      id: data.id.present ? data.id.value : this.id,
      entity: data.entity.present ? data.entity.value : this.entity,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      op: data.op.present ? data.op.value : this.op,
      payload: data.payload.present ? data.payload.value : this.payload,
      lamport: data.lamport.present ? data.lamport.value : this.lamport,
      clientId: data.clientId.present ? data.clientId.value : this.clientId,
      pushed: data.pushed.present ? data.pushed.value : this.pushed,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOp(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('remoteId: $remoteId, ')
          ..write('op: $op, ')
          ..write('payload: $payload, ')
          ..write('lamport: $lamport, ')
          ..write('clientId: $clientId, ')
          ..write('pushed: $pushed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, entity, entityId, remoteId, op, payload,
      lamport, clientId, pushed, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOp &&
          other.id == this.id &&
          other.entity == this.entity &&
          other.entityId == this.entityId &&
          other.remoteId == this.remoteId &&
          other.op == this.op &&
          other.payload == this.payload &&
          other.lamport == this.lamport &&
          other.clientId == this.clientId &&
          other.pushed == this.pushed &&
          other.createdAt == this.createdAt);
}

class SyncOpsCompanion extends UpdateCompanion<SyncOp> {
  final Value<int> id;
  final Value<String> entity;
  final Value<int> entityId;
  final Value<String?> remoteId;
  final Value<SyncOpCode> op;
  final Value<String> payload;
  final Value<int> lamport;
  final Value<String> clientId;
  final Value<bool> pushed;
  final Value<DateTime> createdAt;
  const SyncOpsCompanion({
    this.id = const Value.absent(),
    this.entity = const Value.absent(),
    this.entityId = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.op = const Value.absent(),
    this.payload = const Value.absent(),
    this.lamport = const Value.absent(),
    this.clientId = const Value.absent(),
    this.pushed = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SyncOpsCompanion.insert({
    this.id = const Value.absent(),
    required String entity,
    required int entityId,
    this.remoteId = const Value.absent(),
    required SyncOpCode op,
    required String payload,
    required int lamport,
    required String clientId,
    this.pushed = const Value.absent(),
    required DateTime createdAt,
  })  : entity = Value(entity),
        entityId = Value(entityId),
        op = Value(op),
        payload = Value(payload),
        lamport = Value(lamport),
        clientId = Value(clientId),
        createdAt = Value(createdAt);
  static Insertable<SyncOp> custom({
    Expression<int>? id,
    Expression<String>? entity,
    Expression<int>? entityId,
    Expression<String>? remoteId,
    Expression<String>? op,
    Expression<String>? payload,
    Expression<int>? lamport,
    Expression<String>? clientId,
    Expression<bool>? pushed,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entity != null) 'entity': entity,
      if (entityId != null) 'entity_id': entityId,
      if (remoteId != null) 'remote_id': remoteId,
      if (op != null) 'op': op,
      if (payload != null) 'payload': payload,
      if (lamport != null) 'lamport': lamport,
      if (clientId != null) 'client_id': clientId,
      if (pushed != null) 'pushed': pushed,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SyncOpsCompanion copyWith(
      {Value<int>? id,
      Value<String>? entity,
      Value<int>? entityId,
      Value<String?>? remoteId,
      Value<SyncOpCode>? op,
      Value<String>? payload,
      Value<int>? lamport,
      Value<String>? clientId,
      Value<bool>? pushed,
      Value<DateTime>? createdAt}) {
    return SyncOpsCompanion(
      id: id ?? this.id,
      entity: entity ?? this.entity,
      entityId: entityId ?? this.entityId,
      remoteId: remoteId ?? this.remoteId,
      op: op ?? this.op,
      payload: payload ?? this.payload,
      lamport: lamport ?? this.lamport,
      clientId: clientId ?? this.clientId,
      pushed: pushed ?? this.pushed,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (entity.present) {
      map['entity'] = Variable<String>(entity.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<int>(entityId.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (op.present) {
      map['op'] = Variable<String>($SyncOpsTable.$converterop.toSql(op.value));
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (lamport.present) {
      map['lamport'] = Variable<int>(lamport.value);
    }
    if (clientId.present) {
      map['client_id'] = Variable<String>(clientId.value);
    }
    if (pushed.present) {
      map['pushed'] = Variable<bool>(pushed.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOpsCompanion(')
          ..write('id: $id, ')
          ..write('entity: $entity, ')
          ..write('entityId: $entityId, ')
          ..write('remoteId: $remoteId, ')
          ..write('op: $op, ')
          ..write('payload: $payload, ')
          ..write('lamport: $lamport, ')
          ..write('clientId: $clientId, ')
          ..write('pushed: $pushed, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $AppMetaTable appMeta = $AppMetaTable(this);
  late final $AccountsTable accounts = $AccountsTable(this);
  late final $AccountSnapshotsTable accountSnapshots =
      $AccountSnapshotsTable(this);
  late final $CategoriesTable categories = $CategoriesTable(this);
  late final $TransactionsTable transactions = $TransactionsTable(this);
  late final $BudgetsTable budgets = $BudgetsTable(this);
  late final $SyncOpsTable syncOps = $SyncOpsTable(this);
  late final Index idxTransactionsOccurredAt = Index(
      'idx_transactions_occurred_at',
      'CREATE INDEX idx_transactions_occurred_at ON transactions (occurred_at)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        appMeta,
        accounts,
        accountSnapshots,
        categories,
        transactions,
        budgets,
        syncOps,
        idxTransactionsOccurredAt
      ];
}

typedef $$AppMetaTableCreateCompanionBuilder = AppMetaCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppMetaTableUpdateCompanionBuilder = AppMetaCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppMetaTableFilterComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppMetaTableOrderingComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppMetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppMetaTable> {
  $$AppMetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppMetaTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppMetaTable,
    AppMetaData,
    $$AppMetaTableFilterComposer,
    $$AppMetaTableOrderingComposer,
    $$AppMetaTableAnnotationComposer,
    $$AppMetaTableCreateCompanionBuilder,
    $$AppMetaTableUpdateCompanionBuilder,
    (AppMetaData, BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaData>),
    AppMetaData,
    PrefetchHooks Function()> {
  $$AppMetaTableTableManager(_$AppDatabase db, $AppMetaTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppMetaCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppMetaCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppMetaTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppMetaTable,
    AppMetaData,
    $$AppMetaTableFilterComposer,
    $$AppMetaTableOrderingComposer,
    $$AppMetaTableAnnotationComposer,
    $$AppMetaTableCreateCompanionBuilder,
    $$AppMetaTableUpdateCompanionBuilder,
    (AppMetaData, BaseReferences<_$AppDatabase, $AppMetaTable, AppMetaData>),
    AppMetaData,
    PrefetchHooks Function()>;
typedef $$AccountsTableCreateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  Value<String?> remoteId,
  required AccountType accountType,
  required String name,
  required String currency,
  Value<int> initialBalance,
  Value<bool> archived,
  required DateTime createdAt,
});
typedef $$AccountsTableUpdateCompanionBuilder = AccountsCompanion Function({
  Value<int> id,
  Value<String?> remoteId,
  Value<AccountType> accountType,
  Value<String> name,
  Value<String> currency,
  Value<int> initialBalance,
  Value<bool> archived,
  Value<DateTime> createdAt,
});

class $$AccountsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<AccountType, AccountType, String>
      get accountType => $composableBuilder(
          column: $table.accountType,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get initialBalance => $composableBuilder(
      column: $table.initialBalance,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get accountType => $composableBuilder(
      column: $table.accountType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get initialBalance => $composableBuilder(
      column: $table.initialBalance,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountsTable> {
  $$AccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AccountType, String> get accountType =>
      $composableBuilder(
          column: $table.accountType, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get initialBalance => $composableBuilder(
      column: $table.initialBalance, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AccountsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AccountsTable,
    Account,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
    Account,
    PrefetchHooks Function()> {
  $$AccountsTableTableManager(_$AppDatabase db, $AccountsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<AccountType> accountType = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<int> initialBalance = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              AccountsCompanion(
            id: id,
            remoteId: remoteId,
            accountType: accountType,
            name: name,
            currency: currency,
            initialBalance: initialBalance,
            archived: archived,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            required AccountType accountType,
            required String name,
            required String currency,
            Value<int> initialBalance = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            required DateTime createdAt,
          }) =>
              AccountsCompanion.insert(
            id: id,
            remoteId: remoteId,
            accountType: accountType,
            name: name,
            currency: currency,
            initialBalance: initialBalance,
            archived: archived,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AccountsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AccountsTable,
    Account,
    $$AccountsTableFilterComposer,
    $$AccountsTableOrderingComposer,
    $$AccountsTableAnnotationComposer,
    $$AccountsTableCreateCompanionBuilder,
    $$AccountsTableUpdateCompanionBuilder,
    (Account, BaseReferences<_$AppDatabase, $AccountsTable, Account>),
    Account,
    PrefetchHooks Function()>;
typedef $$AccountSnapshotsTableCreateCompanionBuilder
    = AccountSnapshotsCompanion Function({
  Value<int> id,
  required int accountId,
  required String date,
  required int balanceMinor,
});
typedef $$AccountSnapshotsTableUpdateCompanionBuilder
    = AccountSnapshotsCompanion Function({
  Value<int> id,
  Value<int> accountId,
  Value<String> date,
  Value<int> balanceMinor,
});

class $$AccountSnapshotsTableFilterComposer
    extends Composer<_$AppDatabase, $AccountSnapshotsTable> {
  $$AccountSnapshotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get balanceMinor => $composableBuilder(
      column: $table.balanceMinor, builder: (column) => ColumnFilters(column));
}

class $$AccountSnapshotsTableOrderingComposer
    extends Composer<_$AppDatabase, $AccountSnapshotsTable> {
  $$AccountSnapshotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get date => $composableBuilder(
      column: $table.date, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get balanceMinor => $composableBuilder(
      column: $table.balanceMinor,
      builder: (column) => ColumnOrderings(column));
}

class $$AccountSnapshotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AccountSnapshotsTable> {
  $$AccountSnapshotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get balanceMinor => $composableBuilder(
      column: $table.balanceMinor, builder: (column) => column);
}

class $$AccountSnapshotsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AccountSnapshotsTable,
    AccountSnapshot,
    $$AccountSnapshotsTableFilterComposer,
    $$AccountSnapshotsTableOrderingComposer,
    $$AccountSnapshotsTableAnnotationComposer,
    $$AccountSnapshotsTableCreateCompanionBuilder,
    $$AccountSnapshotsTableUpdateCompanionBuilder,
    (
      AccountSnapshot,
      BaseReferences<_$AppDatabase, $AccountSnapshotsTable, AccountSnapshot>
    ),
    AccountSnapshot,
    PrefetchHooks Function()> {
  $$AccountSnapshotsTableTableManager(
      _$AppDatabase db, $AccountSnapshotsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AccountSnapshotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AccountSnapshotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AccountSnapshotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> accountId = const Value.absent(),
            Value<String> date = const Value.absent(),
            Value<int> balanceMinor = const Value.absent(),
          }) =>
              AccountSnapshotsCompanion(
            id: id,
            accountId: accountId,
            date: date,
            balanceMinor: balanceMinor,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int accountId,
            required String date,
            required int balanceMinor,
          }) =>
              AccountSnapshotsCompanion.insert(
            id: id,
            accountId: accountId,
            date: date,
            balanceMinor: balanceMinor,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AccountSnapshotsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AccountSnapshotsTable,
    AccountSnapshot,
    $$AccountSnapshotsTableFilterComposer,
    $$AccountSnapshotsTableOrderingComposer,
    $$AccountSnapshotsTableAnnotationComposer,
    $$AccountSnapshotsTableCreateCompanionBuilder,
    $$AccountSnapshotsTableUpdateCompanionBuilder,
    (
      AccountSnapshot,
      BaseReferences<_$AppDatabase, $AccountSnapshotsTable, AccountSnapshot>
    ),
    AccountSnapshot,
    PrefetchHooks Function()>;
typedef $$CategoriesTableCreateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  Value<String?> remoteId,
  Value<int?> parentId,
  required String name,
  required String icon,
  required int color,
  required CategoryKind kind,
  Value<bool> isSystem,
  Value<int> sortOrder,
  Value<DateTime?> deletedAt,
  required DateTime updatedAt,
});
typedef $$CategoriesTableUpdateCompanionBuilder = CategoriesCompanion Function({
  Value<int> id,
  Value<String?> remoteId,
  Value<int?> parentId,
  Value<String> name,
  Value<String> icon,
  Value<int> color,
  Value<CategoryKind> kind,
  Value<bool> isSystem,
  Value<int> sortOrder,
  Value<DateTime?> deletedAt,
  Value<DateTime> updatedAt,
});

class $$CategoriesTableFilterComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<CategoryKind, CategoryKind, String> get kind =>
      $composableBuilder(
          column: $table.kind,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<bool> get isSystem => $composableBuilder(
      column: $table.isSystem, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$CategoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get parentId => $composableBuilder(
      column: $table.parentId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get icon => $composableBuilder(
      column: $table.icon, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isSystem => $composableBuilder(
      column: $table.isSystem, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sortOrder => $composableBuilder(
      column: $table.sortOrder, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$CategoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CategoriesTable> {
  $$CategoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<int> get parentId =>
      $composableBuilder(column: $table.parentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumnWithTypeConverter<CategoryKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<bool> get isSystem =>
      $composableBuilder(column: $table.isSystem, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CategoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
    Category,
    PrefetchHooks Function()> {
  $$CategoriesTableTableManager(_$AppDatabase db, $CategoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CategoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CategoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CategoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int?> parentId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> icon = const Value.absent(),
            Value<int> color = const Value.absent(),
            Value<CategoryKind> kind = const Value.absent(),
            Value<bool> isSystem = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              CategoriesCompanion(
            id: id,
            remoteId: remoteId,
            parentId: parentId,
            name: name,
            icon: icon,
            color: color,
            kind: kind,
            isSystem: isSystem,
            sortOrder: sortOrder,
            deletedAt: deletedAt,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int?> parentId = const Value.absent(),
            required String name,
            required String icon,
            required int color,
            required CategoryKind kind,
            Value<bool> isSystem = const Value.absent(),
            Value<int> sortOrder = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
            required DateTime updatedAt,
          }) =>
              CategoriesCompanion.insert(
            id: id,
            remoteId: remoteId,
            parentId: parentId,
            name: name,
            icon: icon,
            color: color,
            kind: kind,
            isSystem: isSystem,
            sortOrder: sortOrder,
            deletedAt: deletedAt,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CategoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CategoriesTable,
    Category,
    $$CategoriesTableFilterComposer,
    $$CategoriesTableOrderingComposer,
    $$CategoriesTableAnnotationComposer,
    $$CategoriesTableCreateCompanionBuilder,
    $$CategoriesTableUpdateCompanionBuilder,
    (Category, BaseReferences<_$AppDatabase, $CategoriesTable, Category>),
    Category,
    PrefetchHooks Function()>;
typedef $$TransactionsTableCreateCompanionBuilder = TransactionsCompanion
    Function({
  Value<int> id,
  Value<String?> remoteId,
  required int accountId,
  Value<int?> categoryId,
  required TransactionType type,
  required int amountMinor,
  required String currency,
  Value<int> rateSnapshot,
  Value<String?> note,
  required DateTime occurredAt,
  Value<int?> transferId,
  Value<bool> autoGenerated,
  required DateTime updatedAt,
  Value<DateTime?> deletedAt,
});
typedef $$TransactionsTableUpdateCompanionBuilder = TransactionsCompanion
    Function({
  Value<int> id,
  Value<String?> remoteId,
  Value<int> accountId,
  Value<int?> categoryId,
  Value<TransactionType> type,
  Value<int> amountMinor,
  Value<String> currency,
  Value<int> rateSnapshot,
  Value<String?> note,
  Value<DateTime> occurredAt,
  Value<int?> transferId,
  Value<bool> autoGenerated,
  Value<DateTime> updatedAt,
  Value<DateTime?> deletedAt,
});

class $$TransactionsTableFilterComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<TransactionType, TransactionType, String>
      get type => $composableBuilder(
          column: $table.type,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get rateSnapshot => $composableBuilder(
      column: $table.rateSnapshot, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get transferId => $composableBuilder(
      column: $table.transferId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get autoGenerated => $composableBuilder(
      column: $table.autoGenerated, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));
}

class $$TransactionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get accountId => $composableBuilder(
      column: $table.accountId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get currency => $composableBuilder(
      column: $table.currency, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get rateSnapshot => $composableBuilder(
      column: $table.rateSnapshot,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get transferId => $composableBuilder(
      column: $table.transferId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get autoGenerated => $composableBuilder(
      column: $table.autoGenerated,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));
}

class $$TransactionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TransactionsTable> {
  $$TransactionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<int> get accountId =>
      $composableBuilder(column: $table.accountId, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TransactionType, String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => column);

  GeneratedColumn<String> get currency =>
      $composableBuilder(column: $table.currency, builder: (column) => column);

  GeneratedColumn<int> get rateSnapshot => $composableBuilder(
      column: $table.rateSnapshot, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
      column: $table.occurredAt, builder: (column) => column);

  GeneratedColumn<int> get transferId => $composableBuilder(
      column: $table.transferId, builder: (column) => column);

  GeneratedColumn<bool> get autoGenerated => $composableBuilder(
      column: $table.autoGenerated, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$TransactionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TransactionsTable,
    Transaction,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (
      Transaction,
      BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>
    ),
    Transaction,
    PrefetchHooks Function()> {
  $$TransactionsTableTableManager(_$AppDatabase db, $TransactionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TransactionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TransactionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TransactionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int> accountId = const Value.absent(),
            Value<int?> categoryId = const Value.absent(),
            Value<TransactionType> type = const Value.absent(),
            Value<int> amountMinor = const Value.absent(),
            Value<String> currency = const Value.absent(),
            Value<int> rateSnapshot = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<DateTime> occurredAt = const Value.absent(),
            Value<int?> transferId = const Value.absent(),
            Value<bool> autoGenerated = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              TransactionsCompanion(
            id: id,
            remoteId: remoteId,
            accountId: accountId,
            categoryId: categoryId,
            type: type,
            amountMinor: amountMinor,
            currency: currency,
            rateSnapshot: rateSnapshot,
            note: note,
            occurredAt: occurredAt,
            transferId: transferId,
            autoGenerated: autoGenerated,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            required int accountId,
            Value<int?> categoryId = const Value.absent(),
            required TransactionType type,
            required int amountMinor,
            required String currency,
            Value<int> rateSnapshot = const Value.absent(),
            Value<String?> note = const Value.absent(),
            required DateTime occurredAt,
            Value<int?> transferId = const Value.absent(),
            Value<bool> autoGenerated = const Value.absent(),
            required DateTime updatedAt,
            Value<DateTime?> deletedAt = const Value.absent(),
          }) =>
              TransactionsCompanion.insert(
            id: id,
            remoteId: remoteId,
            accountId: accountId,
            categoryId: categoryId,
            type: type,
            amountMinor: amountMinor,
            currency: currency,
            rateSnapshot: rateSnapshot,
            note: note,
            occurredAt: occurredAt,
            transferId: transferId,
            autoGenerated: autoGenerated,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TransactionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TransactionsTable,
    Transaction,
    $$TransactionsTableFilterComposer,
    $$TransactionsTableOrderingComposer,
    $$TransactionsTableAnnotationComposer,
    $$TransactionsTableCreateCompanionBuilder,
    $$TransactionsTableUpdateCompanionBuilder,
    (
      Transaction,
      BaseReferences<_$AppDatabase, $TransactionsTable, Transaction>
    ),
    Transaction,
    PrefetchHooks Function()>;
typedef $$BudgetsTableCreateCompanionBuilder = BudgetsCompanion Function({
  Value<int> id,
  Value<String?> remoteId,
  Value<int?> categoryId,
  required String period,
  required int amountMinor,
  Value<int> threshold,
});
typedef $$BudgetsTableUpdateCompanionBuilder = BudgetsCompanion Function({
  Value<int> id,
  Value<String?> remoteId,
  Value<int?> categoryId,
  Value<String> period,
  Value<int> amountMinor,
  Value<int> threshold,
});

class $$BudgetsTableFilterComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get period => $composableBuilder(
      column: $table.period, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get threshold => $composableBuilder(
      column: $table.threshold, builder: (column) => ColumnFilters(column));
}

class $$BudgetsTableOrderingComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get period => $composableBuilder(
      column: $table.period, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get threshold => $composableBuilder(
      column: $table.threshold, builder: (column) => ColumnOrderings(column));
}

class $$BudgetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $BudgetsTable> {
  $$BudgetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<int> get categoryId => $composableBuilder(
      column: $table.categoryId, builder: (column) => column);

  GeneratedColumn<String> get period =>
      $composableBuilder(column: $table.period, builder: (column) => column);

  GeneratedColumn<int> get amountMinor => $composableBuilder(
      column: $table.amountMinor, builder: (column) => column);

  GeneratedColumn<int> get threshold =>
      $composableBuilder(column: $table.threshold, builder: (column) => column);
}

class $$BudgetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BudgetsTable,
    Budget,
    $$BudgetsTableFilterComposer,
    $$BudgetsTableOrderingComposer,
    $$BudgetsTableAnnotationComposer,
    $$BudgetsTableCreateCompanionBuilder,
    $$BudgetsTableUpdateCompanionBuilder,
    (Budget, BaseReferences<_$AppDatabase, $BudgetsTable, Budget>),
    Budget,
    PrefetchHooks Function()> {
  $$BudgetsTableTableManager(_$AppDatabase db, $BudgetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BudgetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BudgetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BudgetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int?> categoryId = const Value.absent(),
            Value<String> period = const Value.absent(),
            Value<int> amountMinor = const Value.absent(),
            Value<int> threshold = const Value.absent(),
          }) =>
              BudgetsCompanion(
            id: id,
            remoteId: remoteId,
            categoryId: categoryId,
            period: period,
            amountMinor: amountMinor,
            threshold: threshold,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<int?> categoryId = const Value.absent(),
            required String period,
            required int amountMinor,
            Value<int> threshold = const Value.absent(),
          }) =>
              BudgetsCompanion.insert(
            id: id,
            remoteId: remoteId,
            categoryId: categoryId,
            period: period,
            amountMinor: amountMinor,
            threshold: threshold,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BudgetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BudgetsTable,
    Budget,
    $$BudgetsTableFilterComposer,
    $$BudgetsTableOrderingComposer,
    $$BudgetsTableAnnotationComposer,
    $$BudgetsTableCreateCompanionBuilder,
    $$BudgetsTableUpdateCompanionBuilder,
    (Budget, BaseReferences<_$AppDatabase, $BudgetsTable, Budget>),
    Budget,
    PrefetchHooks Function()>;
typedef $$SyncOpsTableCreateCompanionBuilder = SyncOpsCompanion Function({
  Value<int> id,
  required String entity,
  required int entityId,
  Value<String?> remoteId,
  required SyncOpCode op,
  required String payload,
  required int lamport,
  required String clientId,
  Value<bool> pushed,
  required DateTime createdAt,
});
typedef $$SyncOpsTableUpdateCompanionBuilder = SyncOpsCompanion Function({
  Value<int> id,
  Value<String> entity,
  Value<int> entityId,
  Value<String?> remoteId,
  Value<SyncOpCode> op,
  Value<String> payload,
  Value<int> lamport,
  Value<String> clientId,
  Value<bool> pushed,
  Value<DateTime> createdAt,
});

class $$SyncOpsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOpsTable> {
  $$SyncOpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entity => $composableBuilder(
      column: $table.entity, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnFilters(column));

  ColumnWithTypeConverterFilters<SyncOpCode, SyncOpCode, String> get op =>
      $composableBuilder(
          column: $table.op,
          builder: (column) => ColumnWithTypeConverterFilters(column));

  ColumnFilters<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lamport => $composableBuilder(
      column: $table.lamport, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get clientId => $composableBuilder(
      column: $table.clientId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get pushed => $composableBuilder(
      column: $table.pushed, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SyncOpsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOpsTable> {
  $$SyncOpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entity => $composableBuilder(
      column: $table.entity, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get remoteId => $composableBuilder(
      column: $table.remoteId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get op => $composableBuilder(
      column: $table.op, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get payload => $composableBuilder(
      column: $table.payload, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lamport => $composableBuilder(
      column: $table.lamport, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get clientId => $composableBuilder(
      column: $table.clientId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get pushed => $composableBuilder(
      column: $table.pushed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncOpsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOpsTable> {
  $$SyncOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entity =>
      $composableBuilder(column: $table.entity, builder: (column) => column);

  GeneratedColumn<int> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SyncOpCode, String> get op =>
      $composableBuilder(column: $table.op, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get lamport =>
      $composableBuilder(column: $table.lamport, builder: (column) => column);

  GeneratedColumn<String> get clientId =>
      $composableBuilder(column: $table.clientId, builder: (column) => column);

  GeneratedColumn<bool> get pushed =>
      $composableBuilder(column: $table.pushed, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncOpsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncOpsTable,
    SyncOp,
    $$SyncOpsTableFilterComposer,
    $$SyncOpsTableOrderingComposer,
    $$SyncOpsTableAnnotationComposer,
    $$SyncOpsTableCreateCompanionBuilder,
    $$SyncOpsTableUpdateCompanionBuilder,
    (SyncOp, BaseReferences<_$AppDatabase, $SyncOpsTable, SyncOp>),
    SyncOp,
    PrefetchHooks Function()> {
  $$SyncOpsTableTableManager(_$AppDatabase db, $SyncOpsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> entity = const Value.absent(),
            Value<int> entityId = const Value.absent(),
            Value<String?> remoteId = const Value.absent(),
            Value<SyncOpCode> op = const Value.absent(),
            Value<String> payload = const Value.absent(),
            Value<int> lamport = const Value.absent(),
            Value<String> clientId = const Value.absent(),
            Value<bool> pushed = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SyncOpsCompanion(
            id: id,
            entity: entity,
            entityId: entityId,
            remoteId: remoteId,
            op: op,
            payload: payload,
            lamport: lamport,
            clientId: clientId,
            pushed: pushed,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String entity,
            required int entityId,
            Value<String?> remoteId = const Value.absent(),
            required SyncOpCode op,
            required String payload,
            required int lamport,
            required String clientId,
            Value<bool> pushed = const Value.absent(),
            required DateTime createdAt,
          }) =>
              SyncOpsCompanion.insert(
            id: id,
            entity: entity,
            entityId: entityId,
            remoteId: remoteId,
            op: op,
            payload: payload,
            lamport: lamport,
            clientId: clientId,
            pushed: pushed,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncOpsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncOpsTable,
    SyncOp,
    $$SyncOpsTableFilterComposer,
    $$SyncOpsTableOrderingComposer,
    $$SyncOpsTableAnnotationComposer,
    $$SyncOpsTableCreateCompanionBuilder,
    $$SyncOpsTableUpdateCompanionBuilder,
    (SyncOp, BaseReferences<_$AppDatabase, $SyncOpsTable, SyncOp>),
    SyncOp,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$AppMetaTableTableManager get appMeta =>
      $$AppMetaTableTableManager(_db, _db.appMeta);
  $$AccountsTableTableManager get accounts =>
      $$AccountsTableTableManager(_db, _db.accounts);
  $$AccountSnapshotsTableTableManager get accountSnapshots =>
      $$AccountSnapshotsTableTableManager(_db, _db.accountSnapshots);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db, _db.categories);
  $$TransactionsTableTableManager get transactions =>
      $$TransactionsTableTableManager(_db, _db.transactions);
  $$BudgetsTableTableManager get budgets =>
      $$BudgetsTableTableManager(_db, _db.budgets);
  $$SyncOpsTableTableManager get syncOps =>
      $$SyncOpsTableTableManager(_db, _db.syncOps);
}
