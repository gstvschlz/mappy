import 'package:drift/drift.dart';

class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get iconName => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Observations extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get description => text().withDefault(const Constant(''))();
  RealColumn get lat => real()();
  RealColumn get lon => real()();
  RealColumn get altitude => real().nullable()();
  RealColumn get accuracy => real().nullable()();
  BoolColumn get manualPlacement =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Photos extends Table {
  TextColumn get id => text()();
  TextColumn get observationId =>
      text().references(Observations, #id, onDelete: KeyAction.cascade)();
  TextColumn get filePath => text()();
  RealColumn get bearing => real().nullable()();
  RealColumn get altitude => real().nullable()();
  DateTimeColumn get takenAt => dateTime()();
  IntColumn get sortIndex => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class TrackPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get trackId => text()();
  RealColumn get lat => real()();
  RealColumn get lon => real()();
  RealColumn get altitude => real().nullable()();
  RealColumn get accuracy => real().nullable()();
  RealColumn get speed => real().nullable()();
  DateTimeColumn get recordedAt => dateTime()();
}

class Tags extends Table {
  TextColumn get id => text()();
  TextColumn get projectId =>
      text().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  // Uniqueness enforced per-project, case-insensitive, by an index defined
  // in the database migration (see AppDatabase.onCreate / onUpgrade).
}

class ObservationTags extends Table {
  TextColumn get observationId =>
      text().references(Observations, #id, onDelete: KeyAction.cascade)();
  TextColumn get tagId =>
      text().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {observationId, tagId};
}
