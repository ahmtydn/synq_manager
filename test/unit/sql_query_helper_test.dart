import 'package:flutter_test/flutter_test.dart';
import 'package:synq_manager/synq_manager.dart';

class TestSync {}

void main() {
  group('SynqQuerySqlConverter', () {
    const tableName = 'items';

    test('converts a simple "where equals" query to SQLite SQL', () {
      final query = (SynqQueryBuilder<TestSync>()
            ..where('completed', isEqualTo: false))
          .build();

      final result = query.toSql(tableName);

      expect(result.sql, 'SELECT * FROM "$tableName" WHERE "completed" = ?');
      expect(result.params, [false]);
    });

    test('converts a query with multiple "where" clauses (AND)', () {
      final query = (SynqQueryBuilder<TestSync>()
            ..where('priority', isGreaterThan: 2)
            ..where('status', isNotEqualTo: 'archived'))
          .build();

      final result = query.toSql(tableName);

      expect(
        result.sql,
        'SELECT * FROM "$tableName" WHERE "priority" > ? AND "status" != ?',
      );
      expect(result.params, [2, 'archived']);
    });

    test('converts a query with OR logical operator', () {
      final query = (SynqQueryBuilder<TestSync>()
            ..logicalOperator = LogicalOperator.or
            ..where('priority', isGreaterThan: 4)
            ..where('status', isEqualTo: 'urgent'))
          .build();

      final result = query.toSql(tableName);

      expect(
        result.sql,
        'SELECT * FROM "$tableName" WHERE "priority" > ? OR "status" = ?',
      );
      expect(result.params, [4, 'urgent']);
    });

    test('converts a query with sorting, limit, and offset', () {
      final query = (SynqQueryBuilder<TestSync>()
            ..orderBy('createdAt', descending: true)
            ..limit(10)
            ..offset(20))
          .build();

      final result = query.toSql(tableName);

      expect(
        result.sql,
        'SELECT * FROM "$tableName" ORDER BY "createdAt" DESC NULLS LAST LIMIT 10 OFFSET 20',
      );
      expect(result.params, isEmpty);
    });

    test('converts a query to PostgreSQL dialect with placeholders', () {
      final query = (SynqQueryBuilder<TestSync>()
            ..where('name', contains: 'test')
            ..where('value', isLessThanOrEqualTo: 100))
          .build();

      final result = query.toSql(tableName, dialect: SqlDialect.postgresql);

      expect(
        result.sql,
        'SELECT * FROM "$tableName" WHERE "name" LIKE \$1 AND "value" <= \$2',
      );
      expect(result.params, ['%test%', 100]);
    });

    test('handles "IN" and "NOT IN" clauses correctly', () {
      final query = (SynqQueryBuilder<TestSync>()
            ..where('status', isIn: ['new', 'open'])
            ..where('id', isNotIn: ['id1', 'id2']))
          .build();

      final result = query.toSql(tableName);

      expect(
        result.sql,
        'SELECT * FROM "$tableName" WHERE "status" IN (?, ?) AND "id" NOT IN (?, ?)',
      );
      expect(result.params, ['new', 'open', 'id1', 'id2']);
    });

    test('handles empty "IN" list to prevent SQL errors', () {
      final query =
          (SynqQueryBuilder<TestSync>()..where('status', isIn: [])).build();
      final result = query.toSql(tableName);
      expect(result.sql, 'SELECT * FROM "$tableName" WHERE 0=1');
    });

    test('handles "BETWEEN" clause correctly', () {
      final query = (SynqQueryBuilder<TestSync>()
            ..where('createdAt', between: [DateTime(2023), DateTime(2024)]))
          .build();

      final result = query.toSql(tableName);

      expect(
        result.sql,
        'SELECT * FROM "$tableName" WHERE "createdAt" BETWEEN ? AND ?',
      );
      expect(result.params, [DateTime(2023), DateTime(2024)]);
    });

    test('handles "IS NULL" and "IS NOT NULL" clauses', () {
      final query = (SynqQueryBuilder<TestSync>()
            ..whereNull('deletedAt')
            ..whereNotNull('updatedAt'))
          .build();

      final result = query.toSql(tableName);

      expect(
        result.sql,
        'SELECT * FROM "$tableName" WHERE "deletedAt" IS NULL AND "updatedAt" IS NOT NULL',
      );
      expect(result.params, isEmpty);
    });

    test('handles "containsIgnoreCase" for SQLite and PostgreSQL', () {
      final query = (SynqQueryBuilder<TestSync>()
            ..where('name', containsIgnoreCase: 'Case'))
          .build();

      // SQLite
      final sqliteResult = query.toSql(tableName);
      expect(
        sqliteResult.sql,
        'SELECT * FROM "$tableName" WHERE LOWER("name") LIKE ?',
      );
      expect(sqliteResult.params, ['%case%']);

      // PostgreSQL
      final pgResult = query.toSql(tableName, dialect: SqlDialect.postgresql);
      expect(pgResult.sql, 'SELECT * FROM "$tableName" WHERE "name" ILIKE \$1');
      expect(pgResult.params, ['%Case%']);
    });

    test('handles composite "OR" filter', () {
      final query = (SynqQueryBuilder<TestSync>()
            ..where('category', isEqualTo: 'A')
            ..or([
              const Filter('status', FilterOperator.equals, 'new'),
              const Filter('priority', FilterOperator.greaterThan, 3),
            ]))
          .build();

      final result = query.toSql(tableName);

      expect(
        result.sql,
        'SELECT * FROM "$tableName" WHERE "category" = ? AND ("status" = ? OR "priority" > ?)',
      );
      expect(result.params, ['A', 'new', 3]);
    });

    test('uses customBuilder for unsupported operators', () {
      final query = (SynqQueryBuilder<TestSync>()
            ..where(
              'location',
              matches: 'some_pattern',
            )) // REGEXP is dialect-specific
          .build();

      final result = query.toSql(
        tableName,
        customBuilder: (filter, getPlaceholder, params) {
          if (filter.operator == FilterOperator.matches) {
            params.add(filter.value);
            return '"${filter.field}" REGEXP ${getPlaceholder()}';
          }
          return null;
        },
      );

      expect(
        result.sql,
        'SELECT * FROM "$tableName" WHERE "location" REGEXP ?',
      );
      expect(result.params, ['some_pattern']);
    });
  });
}
