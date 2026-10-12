// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'consumption_log.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetConsumptionLogCollection on Isar {
  IsarCollection<ConsumptionLog> get consumptionLogs => this.collection();
}

const ConsumptionLogSchema = CollectionSchema(
  name: r'ConsumptionLog',
  id: 2223654273564831900,
  properties: {
    r'acidScore': PropertySchema(
      id: 0,
      name: r'acidScore',
      type: IsarType.long,
    ),
    r'consumedAt': PropertySchema(
      id: 1,
      name: r'consumedAt',
      type: IsarType.dateTime,
    ),
    r'productDetails': PropertySchema(
      id: 2,
      name: r'productDetails',
      type: IsarType.string,
    )
  },
  estimateSize: _consumptionLogEstimateSize,
  serialize: _consumptionLogSerialize,
  deserialize: _consumptionLogDeserialize,
  deserializeProp: _consumptionLogDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {},
  embeddedSchemas: {},
  getId: _consumptionLogGetId,
  getLinks: _consumptionLogGetLinks,
  attach: _consumptionLogAttach,
  version: '3.1.0+1',
);

int _consumptionLogEstimateSize(
  ConsumptionLog object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.productDetails.length * 3;
  return bytesCount;
}

void _consumptionLogSerialize(
  ConsumptionLog object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.acidScore);
  writer.writeDateTime(offsets[1], object.consumedAt);
  writer.writeString(offsets[2], object.productDetails);
}

ConsumptionLog _consumptionLogDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ConsumptionLog();
  object.acidScore = reader.readLong(offsets[0]);
  object.consumedAt = reader.readDateTime(offsets[1]);
  object.id = id;
  object.productDetails = reader.readString(offsets[2]);
  return object;
}

P _consumptionLogDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _consumptionLogGetId(ConsumptionLog object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _consumptionLogGetLinks(ConsumptionLog object) {
  return [];
}

void _consumptionLogAttach(
    IsarCollection<dynamic> col, Id id, ConsumptionLog object) {
  object.id = id;
}

extension ConsumptionLogQueryWhereSort
    on QueryBuilder<ConsumptionLog, ConsumptionLog, QWhere> {
  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ConsumptionLogQueryWhere
    on QueryBuilder<ConsumptionLog, ConsumptionLog, QWhereClause> {
  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension ConsumptionLogQueryFilter
    on QueryBuilder<ConsumptionLog, ConsumptionLog, QFilterCondition> {
  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      acidScoreEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acidScore',
        value: value,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      acidScoreGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'acidScore',
        value: value,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      acidScoreLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'acidScore',
        value: value,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      acidScoreBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'acidScore',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      consumedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'consumedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      consumedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'consumedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      consumedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'consumedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      consumedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'consumedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      productDetailsEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'productDetails',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      productDetailsGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'productDetails',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      productDetailsLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'productDetails',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      productDetailsBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'productDetails',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      productDetailsStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'productDetails',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      productDetailsEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'productDetails',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      productDetailsContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'productDetails',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      productDetailsMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'productDetails',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      productDetailsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'productDetails',
        value: '',
      ));
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterFilterCondition>
      productDetailsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'productDetails',
        value: '',
      ));
    });
  }
}

extension ConsumptionLogQueryObject
    on QueryBuilder<ConsumptionLog, ConsumptionLog, QFilterCondition> {}

extension ConsumptionLogQueryLinks
    on QueryBuilder<ConsumptionLog, ConsumptionLog, QFilterCondition> {}

extension ConsumptionLogQuerySortBy
    on QueryBuilder<ConsumptionLog, ConsumptionLog, QSortBy> {
  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterSortBy> sortByAcidScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acidScore', Sort.asc);
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterSortBy>
      sortByAcidScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acidScore', Sort.desc);
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterSortBy>
      sortByConsumedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAt', Sort.asc);
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterSortBy>
      sortByConsumedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAt', Sort.desc);
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterSortBy>
      sortByProductDetails() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productDetails', Sort.asc);
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterSortBy>
      sortByProductDetailsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productDetails', Sort.desc);
    });
  }
}

extension ConsumptionLogQuerySortThenBy
    on QueryBuilder<ConsumptionLog, ConsumptionLog, QSortThenBy> {
  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterSortBy> thenByAcidScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acidScore', Sort.asc);
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterSortBy>
      thenByAcidScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acidScore', Sort.desc);
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterSortBy>
      thenByConsumedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAt', Sort.asc);
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterSortBy>
      thenByConsumedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'consumedAt', Sort.desc);
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterSortBy>
      thenByProductDetails() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productDetails', Sort.asc);
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QAfterSortBy>
      thenByProductDetailsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'productDetails', Sort.desc);
    });
  }
}

extension ConsumptionLogQueryWhereDistinct
    on QueryBuilder<ConsumptionLog, ConsumptionLog, QDistinct> {
  QueryBuilder<ConsumptionLog, ConsumptionLog, QDistinct>
      distinctByAcidScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acidScore');
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QDistinct>
      distinctByConsumedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'consumedAt');
    });
  }

  QueryBuilder<ConsumptionLog, ConsumptionLog, QDistinct>
      distinctByProductDetails({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'productDetails',
          caseSensitive: caseSensitive);
    });
  }
}

extension ConsumptionLogQueryProperty
    on QueryBuilder<ConsumptionLog, ConsumptionLog, QQueryProperty> {
  QueryBuilder<ConsumptionLog, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ConsumptionLog, int, QQueryOperations> acidScoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acidScore');
    });
  }

  QueryBuilder<ConsumptionLog, DateTime, QQueryOperations>
      consumedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'consumedAt');
    });
  }

  QueryBuilder<ConsumptionLog, String, QQueryOperations>
      productDetailsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'productDetails');
    });
  }
}
