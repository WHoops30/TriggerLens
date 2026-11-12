// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pantry_item.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetPantryItemCollection on Isar {
  IsarCollection<PantryItem> get pantryItems => this.collection();
}

const PantryItemSchema = CollectionSchema(
  name: r'PantryItem',
  id: -4985693046440909510,
  properties: {
    r'acidScore': PropertySchema(
      id: 0,
      name: r'acidScore',
      type: IsarType.long,
    ),
    r'dateScanned': PropertySchema(
      id: 1,
      name: r'dateScanned',
      type: IsarType.dateTime,
    ),
    r'drinkCategory': PropertySchema(
      id: 2,
      name: r'drinkCategory',
      type: IsarType.string,
    ),
    r'imagePath': PropertySchema(
      id: 3,
      name: r'imagePath',
      type: IsarType.string,
    ),
    r'isConsumed': PropertySchema(
      id: 4,
      name: r'isConsumed',
      type: IsarType.bool,
    ),
    r'isDiluted': PropertySchema(
      id: 5,
      name: r'isDiluted',
      type: IsarType.bool,
    ),
    r'isEmptyStomach': PropertySchema(
      id: 6,
      name: r'isEmptyStomach',
      type: IsarType.bool,
    ),
    r'isFavorite': PropertySchema(
      id: 7,
      name: r'isFavorite',
      type: IsarType.bool,
    ),
    r'name': PropertySchema(
      id: 8,
      name: r'name',
      type: IsarType.string,
    ),
    r'portionCount': PropertySchema(
      id: 9,
      name: r'portionCount',
      type: IsarType.double,
    ),
    r'portionMeasurement': PropertySchema(
      id: 10,
      name: r'portionMeasurement',
      type: IsarType.string,
    ),
    r'rawText': PropertySchema(
      id: 11,
      name: r'rawText',
      type: IsarType.string,
    ),
    r'riskLevel': PropertySchema(
      id: 12,
      name: r'riskLevel',
      type: IsarType.string,
    ),
    r'symptoms': PropertySchema(
      id: 13,
      name: r'symptoms',
      type: IsarType.string,
    ),
    r'userId': PropertySchema(
      id: 14,
      name: r'userId',
      type: IsarType.string,
    )
  },
  estimateSize: _pantryItemEstimateSize,
  serialize: _pantryItemSerialize,
  deserialize: _pantryItemDeserialize,
  deserializeProp: _pantryItemDeserializeProp,
  idName: r'id',
  indexes: {
    r'userId': IndexSchema(
      id: -2005826577402374815,
      name: r'userId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'userId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _pantryItemGetId,
  getLinks: _pantryItemGetLinks,
  attach: _pantryItemAttach,
  version: '3.1.0+1',
);

int _pantryItemEstimateSize(
  PantryItem object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.drinkCategory.length * 3;
  {
    final value = object.imagePath;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.name.length * 3;
  bytesCount += 3 + object.portionMeasurement.length * 3;
  bytesCount += 3 + object.rawText.length * 3;
  bytesCount += 3 + object.riskLevel.length * 3;
  bytesCount += 3 + object.symptoms.length * 3;
  bytesCount += 3 + object.userId.length * 3;
  return bytesCount;
}

void _pantryItemSerialize(
  PantryItem object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.acidScore);
  writer.writeDateTime(offsets[1], object.dateScanned);
  writer.writeString(offsets[2], object.drinkCategory);
  writer.writeString(offsets[3], object.imagePath);
  writer.writeBool(offsets[4], object.isConsumed);
  writer.writeBool(offsets[5], object.isDiluted);
  writer.writeBool(offsets[6], object.isEmptyStomach);
  writer.writeBool(offsets[7], object.isFavorite);
  writer.writeString(offsets[8], object.name);
  writer.writeDouble(offsets[9], object.portionCount);
  writer.writeString(offsets[10], object.portionMeasurement);
  writer.writeString(offsets[11], object.rawText);
  writer.writeString(offsets[12], object.riskLevel);
  writer.writeString(offsets[13], object.symptoms);
  writer.writeString(offsets[14], object.userId);
}

PantryItem _pantryItemDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = PantryItem();
  object.acidScore = reader.readLong(offsets[0]);
  object.dateScanned = reader.readDateTime(offsets[1]);
  object.drinkCategory = reader.readString(offsets[2]);
  object.id = id;
  object.imagePath = reader.readStringOrNull(offsets[3]);
  object.isConsumed = reader.readBool(offsets[4]);
  object.isDiluted = reader.readBool(offsets[5]);
  object.isEmptyStomach = reader.readBool(offsets[6]);
  object.isFavorite = reader.readBool(offsets[7]);
  object.name = reader.readString(offsets[8]);
  object.portionCount = reader.readDouble(offsets[9]);
  object.portionMeasurement = reader.readString(offsets[10]);
  object.rawText = reader.readString(offsets[11]);
  object.riskLevel = reader.readString(offsets[12]);
  object.symptoms = reader.readString(offsets[13]);
  object.userId = reader.readString(offsets[14]);
  return object;
}

P _pantryItemDeserializeProp<P>(
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
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readBool(offset)) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    case 7:
      return (reader.readBool(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    case 9:
      return (reader.readDouble(offset)) as P;
    case 10:
      return (reader.readString(offset)) as P;
    case 11:
      return (reader.readString(offset)) as P;
    case 12:
      return (reader.readString(offset)) as P;
    case 13:
      return (reader.readString(offset)) as P;
    case 14:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _pantryItemGetId(PantryItem object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _pantryItemGetLinks(PantryItem object) {
  return [];
}

void _pantryItemAttach(IsarCollection<dynamic> col, Id id, PantryItem object) {
  object.id = id;
}

extension PantryItemQueryWhereSort
    on QueryBuilder<PantryItem, PantryItem, QWhere> {
  QueryBuilder<PantryItem, PantryItem, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension PantryItemQueryWhere
    on QueryBuilder<PantryItem, PantryItem, QWhereClause> {
  QueryBuilder<PantryItem, PantryItem, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<PantryItem, PantryItem, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterWhereClause> idBetween(
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

  QueryBuilder<PantryItem, PantryItem, QAfterWhereClause> userIdEqualTo(
      String userId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'userId',
        value: [userId],
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterWhereClause> userIdNotEqualTo(
      String userId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'userId',
              lower: [],
              upper: [userId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'userId',
              lower: [userId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'userId',
              lower: [userId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'userId',
              lower: [],
              upper: [userId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension PantryItemQueryFilter
    on QueryBuilder<PantryItem, PantryItem, QFilterCondition> {
  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> acidScoreEqualTo(
      int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'acidScore',
        value: value,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
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

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> acidScoreLessThan(
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

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> acidScoreBetween(
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

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      dateScannedEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'dateScanned',
        value: value,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      dateScannedGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'dateScanned',
        value: value,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      dateScannedLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'dateScanned',
        value: value,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      dateScannedBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'dateScanned',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      drinkCategoryEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'drinkCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      drinkCategoryGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'drinkCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      drinkCategoryLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'drinkCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      drinkCategoryBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'drinkCategory',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      drinkCategoryStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'drinkCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      drinkCategoryEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'drinkCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      drinkCategoryContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'drinkCategory',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      drinkCategoryMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'drinkCategory',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      drinkCategoryIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'drinkCategory',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      drinkCategoryIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'drinkCategory',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> idBetween(
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

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      imagePathIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'imagePath',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      imagePathIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'imagePath',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> imagePathEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      imagePathGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'imagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> imagePathLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'imagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> imagePathBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'imagePath',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      imagePathStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'imagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> imagePathEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'imagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> imagePathContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'imagePath',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> imagePathMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'imagePath',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      imagePathIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'imagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      imagePathIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'imagePath',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> isConsumedEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isConsumed',
        value: value,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> isDilutedEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDiluted',
        value: value,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      isEmptyStomachEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isEmptyStomach',
        value: value,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> isFavoriteEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isFavorite',
        value: value,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> nameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> nameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> nameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> nameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> nameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> nameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      portionCountEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'portionCount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      portionCountGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'portionCount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      portionCountLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'portionCount',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      portionCountBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'portionCount',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      portionMeasurementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'portionMeasurement',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      portionMeasurementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'portionMeasurement',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      portionMeasurementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'portionMeasurement',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      portionMeasurementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'portionMeasurement',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      portionMeasurementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'portionMeasurement',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      portionMeasurementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'portionMeasurement',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      portionMeasurementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'portionMeasurement',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      portionMeasurementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'portionMeasurement',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      portionMeasurementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'portionMeasurement',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      portionMeasurementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'portionMeasurement',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> rawTextEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rawText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      rawTextGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'rawText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> rawTextLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'rawText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> rawTextBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'rawText',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> rawTextStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'rawText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> rawTextEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'rawText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> rawTextContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'rawText',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> rawTextMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'rawText',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> rawTextIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'rawText',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      rawTextIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'rawText',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> riskLevelEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'riskLevel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      riskLevelGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'riskLevel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> riskLevelLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'riskLevel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> riskLevelBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'riskLevel',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      riskLevelStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'riskLevel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> riskLevelEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'riskLevel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> riskLevelContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'riskLevel',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> riskLevelMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'riskLevel',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      riskLevelIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'riskLevel',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      riskLevelIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'riskLevel',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> symptomsEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'symptoms',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      symptomsGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'symptoms',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> symptomsLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'symptoms',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> symptomsBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'symptoms',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      symptomsStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'symptoms',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> symptomsEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'symptoms',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> symptomsContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'symptoms',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> symptomsMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'symptoms',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      symptomsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'symptoms',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      symptomsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'symptoms',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> userIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> userIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> userIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> userIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'userId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> userIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> userIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> userIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'userId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> userIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'userId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition> userIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'userId',
        value: '',
      ));
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterFilterCondition>
      userIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'userId',
        value: '',
      ));
    });
  }
}

extension PantryItemQueryObject
    on QueryBuilder<PantryItem, PantryItem, QFilterCondition> {}

extension PantryItemQueryLinks
    on QueryBuilder<PantryItem, PantryItem, QFilterCondition> {}

extension PantryItemQuerySortBy
    on QueryBuilder<PantryItem, PantryItem, QSortBy> {
  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByAcidScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acidScore', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByAcidScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acidScore', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByDateScanned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateScanned', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByDateScannedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateScanned', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByDrinkCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'drinkCategory', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByDrinkCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'drinkCategory', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePath', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePath', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByIsConsumed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isConsumed', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByIsConsumedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isConsumed', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByIsDiluted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDiluted', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByIsDilutedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDiluted', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByIsEmptyStomach() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEmptyStomach', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy>
      sortByIsEmptyStomachDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEmptyStomach', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByIsFavoriteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByPortionCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'portionCount', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByPortionCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'portionCount', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy>
      sortByPortionMeasurement() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'portionMeasurement', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy>
      sortByPortionMeasurementDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'portionMeasurement', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByRawText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawText', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByRawTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawText', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByRiskLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'riskLevel', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByRiskLevelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'riskLevel', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortBySymptoms() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'symptoms', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortBySymptomsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'symptoms', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> sortByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension PantryItemQuerySortThenBy
    on QueryBuilder<PantryItem, PantryItem, QSortThenBy> {
  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByAcidScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acidScore', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByAcidScoreDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'acidScore', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByDateScanned() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateScanned', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByDateScannedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'dateScanned', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByDrinkCategory() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'drinkCategory', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByDrinkCategoryDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'drinkCategory', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByImagePath() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePath', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByImagePathDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'imagePath', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByIsConsumed() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isConsumed', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByIsConsumedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isConsumed', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByIsDiluted() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDiluted', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByIsDilutedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDiluted', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByIsEmptyStomach() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEmptyStomach', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy>
      thenByIsEmptyStomachDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isEmptyStomach', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByIsFavoriteDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isFavorite', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByPortionCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'portionCount', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByPortionCountDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'portionCount', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy>
      thenByPortionMeasurement() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'portionMeasurement', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy>
      thenByPortionMeasurementDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'portionMeasurement', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByRawText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawText', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByRawTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'rawText', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByRiskLevel() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'riskLevel', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByRiskLevelDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'riskLevel', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenBySymptoms() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'symptoms', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenBySymptomsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'symptoms', Sort.desc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QAfterSortBy> thenByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension PantryItemQueryWhereDistinct
    on QueryBuilder<PantryItem, PantryItem, QDistinct> {
  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctByAcidScore() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'acidScore');
    });
  }

  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctByDateScanned() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'dateScanned');
    });
  }

  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctByDrinkCategory(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'drinkCategory',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctByImagePath(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'imagePath', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctByIsConsumed() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isConsumed');
    });
  }

  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctByIsDiluted() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDiluted');
    });
  }

  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctByIsEmptyStomach() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isEmptyStomach');
    });
  }

  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctByIsFavorite() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isFavorite');
    });
  }

  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctByPortionCount() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'portionCount');
    });
  }

  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctByPortionMeasurement(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'portionMeasurement',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctByRawText(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'rawText', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctByRiskLevel(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'riskLevel', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctBySymptoms(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'symptoms', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<PantryItem, PantryItem, QDistinct> distinctByUserId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userId', caseSensitive: caseSensitive);
    });
  }
}

extension PantryItemQueryProperty
    on QueryBuilder<PantryItem, PantryItem, QQueryProperty> {
  QueryBuilder<PantryItem, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<PantryItem, int, QQueryOperations> acidScoreProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'acidScore');
    });
  }

  QueryBuilder<PantryItem, DateTime, QQueryOperations> dateScannedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dateScanned');
    });
  }

  QueryBuilder<PantryItem, String, QQueryOperations> drinkCategoryProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'drinkCategory');
    });
  }

  QueryBuilder<PantryItem, String?, QQueryOperations> imagePathProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'imagePath');
    });
  }

  QueryBuilder<PantryItem, bool, QQueryOperations> isConsumedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isConsumed');
    });
  }

  QueryBuilder<PantryItem, bool, QQueryOperations> isDilutedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDiluted');
    });
  }

  QueryBuilder<PantryItem, bool, QQueryOperations> isEmptyStomachProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isEmptyStomach');
    });
  }

  QueryBuilder<PantryItem, bool, QQueryOperations> isFavoriteProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isFavorite');
    });
  }

  QueryBuilder<PantryItem, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<PantryItem, double, QQueryOperations> portionCountProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'portionCount');
    });
  }

  QueryBuilder<PantryItem, String, QQueryOperations>
      portionMeasurementProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'portionMeasurement');
    });
  }

  QueryBuilder<PantryItem, String, QQueryOperations> rawTextProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'rawText');
    });
  }

  QueryBuilder<PantryItem, String, QQueryOperations> riskLevelProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'riskLevel');
    });
  }

  QueryBuilder<PantryItem, String, QQueryOperations> symptomsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'symptoms');
    });
  }

  QueryBuilder<PantryItem, String, QQueryOperations> userIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userId');
    });
  }
}
