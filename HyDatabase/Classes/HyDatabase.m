//
//  HyDatabase.m
//  HyDatabase
//
//  Created by hydreamit on 2017/3/9.
//  Copyright © 2017 hydreamit. All rights reserved.
//

#import "HyDatabase.h"
#import <objc/message.h>
#import "sqlite3.h"


@interface HyDatabaseTable()
@property (nonatomic,assign) Class cls;
@property (nonatomic,copy) NSString *name;
@property (nonatomic,copy) NSString *primaryKey;
@property (nonatomic,strong) NSArray<NSString *> *columnNameAarray;
@end
@implementation HyDatabaseTable
- (NSString *)tableName {
    return [NSString stringWithFormat:@"%@_%@", NSStringFromClass(self.cls), self.name];
}
@end




@interface HyDatabase() {
    sqlite3 *_db;
}
@property (nonatomic,copy) NSString *path;
@end


@implementation HyDatabase

+ (instancetype)databaseWithName:(NSString *)name {
    if (!name.length) {
        return nil;
    }
    NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:name];
    return [self databaseWithPath:path];
}

+ (instancetype)databaseWithPath:(NSString *)path {
    HyDatabase *db = [[HyDatabase alloc] init];
    if (![[path componentsSeparatedByString:@"."].lastObject isEqualToString:@"sqlite"]) {
        path = [NSString stringWithFormat:@"%@.sqlite", path];
    }
    db.path = path;
    return db;
}

- (BOOL)createTableWithClass:(Class<HyDatabaseObjectProtocol>)cls {
    return [self createTableWithClass:cls name:NSStringFromClass(cls)];
}

- (BOOL)createTableWithClass:(Class<HyDatabaseObjectProtocol>)cls
                        name:(NSString *)name {
    
    if (!cls || !name.length) {
        return NO;
    }
    
    if (![cls conformsToProtocol:@protocol(HyDatabaseObjectProtocol)]) {
        NSLog(@"%@须遵守HyDatabaseObjectProtocol协议", NSStringFromClass(cls));
        return NO;
    }
    
    if (![cls respondsToSelector:@selector(db_primaryKey)]) {
        NSLog(@"%@没有设置primaryKey", NSStringFromClass(cls));
        return NO;
    }
    
    NSString *primaryKey = [cls db_primaryKey];
    NSDictionary *typeDict = [self ivarNameSqliteTypeDicForClass:cls];
    if (![typeDict.allKeys containsObject:primaryKey]) {
        NSLog(@"primaryKey: %@ 不是 %@ 的属性",primaryKey, NSStringFromClass(cls));
        return NO;
    }
    
    NSString *tableName = [NSString stringWithFormat:@"%@_%@", NSStringFromClass(cls), name];
    NSMutableArray *nameTypes = [NSMutableArray array];
    [typeDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [nameTypes addObject:[NSString stringWithFormat:@"%@ %@", key, obj]];
    }];
    
    HyDatabaseTable *table = [self tableWithName:name];
    if ([self ifNeedsUptateTableWithClass:cls name:name]) {
        NSMutableArray *sqls = @[].mutableCopy;
        NSString *tempTableName = [NSString stringWithFormat:@"temp_%@", tableName];
        [sqls addObject:[NSString stringWithFormat:@"drop table if exists %@;", tempTableName]];
        [sqls addObject:[NSString stringWithFormat:@"create table if not exists %@(%@, primary key(%@));", tempTableName, [nameTypes componentsJoinedByString:@","], primaryKey]];
        [sqls addObject:[NSString stringWithFormat:@"insert into %@(%@) select %@ from %@;", tempTableName, primaryKey, primaryKey, tableName]];
        [table.columnNameAarray enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([typeDict.allKeys containsObject:obj]) {
                [sqls addObject:[NSString stringWithFormat:@"update %@ set %@ = (select %@ from %@ where %@.%@ = %@.%@);", tempTableName, obj, obj, tableName, tempTableName, primaryKey, tableName, primaryKey]];
            }
        }];
        [sqls addObject:[NSString stringWithFormat:@"drop table if exists %@;", tableName]];
        [sqls addObject:[NSString stringWithFormat:@"alter table %@ rename to %@;", tempTableName, tableName]];
        return [self dealSqls:sqls];
    } else {
        if (!table) {
            NSString *createTableSql = [NSString stringWithFormat:@"create table if not exists %@(%@, primary key(%@))", tableName, [nameTypes componentsJoinedByString:@","], primaryKey];
            return [self execSql:createTableSql];
        } else {
            NSLog(@"table %@ 已经存在", name);
            return YES;
        }
    }
}





#pragma mark - insert objects methods
- (BOOL)insertOrUpdateObject:(NSObject *)object {
    return [self insertOrUpdateObject:object into:NSStringFromClass(object.class)];
}

- (BOOL)insertOrUpdateObject:(NSObject *)object into:(NSString *)name {
    if (!object || object == NSNull.null || !name.length) {
        return NO;
    }
    return  [self insertOrUpdateObjects:@[object] into:name];
}

- (BOOL)insertOrUpdateObjectWithDict:(NSDictionary<NSString *, id> *)dict into:(NSString *)name {
    if (!dict.allKeys.count || !name.length) {
        return NO;
    }
    return [self insertOrUpdateObjectWithDictArray:@[dict] into:name];
}

- (BOOL)insertOrUpdateObjects:(NSArray<NSObject *> *)objects into:(NSString *)name {
    if (!objects.count || !name.length) {
        return NO;
    }
       
    if ([self createTableWithClass:objects.firstObject.class name:name]) {
        
        NSMutableArray<NSString *> *sqls = @[].mutableCopy;
        NSMutableArray<NSArray *> *valuesArray = @[].mutableCopy;
        for (NSInteger index = 0; index < objects.count; ++index) {
            NSObject *object = objects[index];
            
            NSString *primaryKey = [object.class db_primaryKey];
            id primaryKeyValue = [object valueForKeyPath:primaryKey];
            NSString *tableName = [NSString stringWithFormat:@"%@_%@", NSStringFromClass(object.class), name];
            NSArray *primaryKeyResult = [self querySql:[NSString stringWithFormat:@"select * from %@ where %@ = '%@'",tableName, primaryKey, primaryKeyValue]];
            
            BOOL isUpdate = primaryKeyResult.count;
            NSMutableArray *names = @[].mutableCopy;
            NSMutableArray *values = @[].mutableCopy;
            NSMutableArray *argments = @[].mutableCopy;
            [[self ivarNameTypeDicForClass:object.class] enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                id value = [object valueForKeyPath:key] ?: [NSNull null];
                if (isUpdate) {
                    if (![primaryKey isEqualToString:key]) {
                        [names addObject:[NSString stringWithFormat:@"%@ = ?", key]];
                        [values addObject:value];
                    }
                } else {
                    [names addObject:key];
                    [values addObject:value];
                    [argments addObject:@"?"];
                }
            }];
            NSString *sql = @"";
            if (isUpdate) {
                sql = [NSString stringWithFormat:@"update %@ set %@ where %@ = '%@'", tableName, [names componentsJoinedByString:@","], primaryKey, primaryKeyValue];
            } else {
                sql = [NSString stringWithFormat:@"insert into %@(%@) values (%@);", tableName, [names componentsJoinedByString:@","], [argments componentsJoinedByString:@","]];;
            }
            [sqls addObject:sql];
            [valuesArray addObject:values];
        }
        return [self bindValueWithSqls:sqls valuesArray:valuesArray];
    }
    return NO;
}

- (BOOL)insertOrUpdateObjectWithDictArray:(NSArray<NSDictionary<NSString *, id> *> *)dictArray into:(NSString *)name {
    
    if (!dictArray.count || !name.length) {
        return NO;
    }
    
    HyDatabaseTable *table = [self tableWithName:name];
    if (!table) {
        NSLog(@"%@表不存在", name);
        return NO;
    }
    
    NSMutableArray<NSString *> *sqls = @[].mutableCopy;
    NSMutableArray<NSArray *> *valuesArray = @[].mutableCopy;
    for (NSInteger index = 0; index < dictArray.count; ++index) {
        NSDictionary *dict = dictArray[index];
        
        NSString *primaryKey = table.primaryKey;
        id primaryKeyValue = [dict valueForKeyPath:primaryKey];
        NSString *tableName = [table tableName];
        NSArray *primaryKeyResult = [self querySql:[NSString stringWithFormat:@"select * from %@ where %@ = '%@'",tableName, primaryKey, primaryKeyValue]];

        BOOL isUpdate = primaryKeyResult.count;
        NSMutableArray *names = @[].mutableCopy;
        NSMutableArray *values = @[].mutableCopy;
        NSMutableArray *argments = @[].mutableCopy;
        [dict enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            if ([table.columnNameAarray containsObject:key]) {
                id value = obj;
                if (isUpdate) {
                    if (![primaryKey isEqualToString:key]) {
                        [names addObject:[NSString stringWithFormat:@"%@ = ?", key]];
                        [values addObject:value];
                    }
                } else {
                    [names addObject:key];
                    [values addObject:value];
                    [argments addObject:@"?"];
                }
            }
        }];

        if (!names.count) {
            continue;
        }

        NSString *sql = @"";
        if (isUpdate) {
            sql = [NSString stringWithFormat:@"update %@ set %@ where %@ = '%@'", tableName, [names componentsJoinedByString:@","], primaryKey, primaryKeyValue];
        } else {
            sql = [NSString stringWithFormat:@"insert into %@(%@) values (%@);", tableName, [names componentsJoinedByString:@","], [argments componentsJoinedByString:@","]];;
        }
        
        [sqls addObject:sql];
        [valuesArray addObject:values];
        
    }
    return [self bindValueWithSqls:sqls valuesArray:valuesArray];
}





#pragma mark - delete object methods
- (BOOL)deleteObject:(NSObject *)object {
    if (!object) {
        return NO;
    }
    return [self deleteObject:object from:NSStringFromClass(object.class)];
}

- (BOOL)deleteObject:(NSObject *)object
                from:(NSString *)name {
    if (!object || !name.length) {
        return NO;
    }
    
    if (![object.class conformsToProtocol:@protocol(HyDatabaseObjectProtocol)]) {
        NSLog(@"%@必须遵守HyDatabaseObjectProtocol协议", NSStringFromClass(object.class));
        return NO;
    }
    
    NSString *primaryKey = [object.class db_primaryKey];
    id primaryValue = [object valueForKeyPath:primaryKey];
    NSString *tableName = [NSString stringWithFormat:@"%@_%@", object.class, name];
        
    return [self execSql:[NSString stringWithFormat:@"delete from %@ where %@ = '%@'", tableName, primaryKey, primaryValue]];
}

- (BOOL)deleteObjectFrom:(NSString *)name where:(NSString * _Nullable)where {
    
    if (!name.length) {
        return NO;
    }
    
    HyDatabaseTable *table = [self tableWithName:name];
    if (!table) {
        NSLog(@"表%@不存在", name);
        return NO;
    }
    
    NSString *sql = [NSString stringWithFormat:@"delete from %@", [table tableName]];
    if (where.length) {
        sql = [sql stringByAppendingFormat:@" where %@", where];
    }
    
    return [self execSql:sql];
}






#pragma mark - get object methods
- (NSArray *)objectsOfTableName:(NSString *)name {
    return [self objectsOfTableName:name where:nil];
}

- (NSArray *)objectsOfTableName:(NSString *)name where:(NSString *)where {
    
    if (!name.length) {
        return nil;
    }
    
    __block Class cls = NULL;
    [self.allTables enumerateObjectsUsingBlock:^(HyDatabaseTable * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.name isEqualToString:name]) {
            cls = obj.cls;
            *stop = YES;
        }
    }];
    
    if (!cls) {
        NSLog(@"没有表%@",name);
        return nil;
    }
    
    return [self objectsOfClass:cls
                      tableName:[NSString stringWithFormat:@"%@_%@", NSStringFromClass(cls), name]
                          where:where];
}

- (NSArray *)objectsOfClass:(Class<HyDatabaseObjectProtocol>)cls {
    
    if (!cls) { return nil; }
    
    NSMutableArray *objects = @[].mutableCopy;
    [self.allTables enumerateObjectsUsingBlock:^(HyDatabaseTable * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (cls == obj.class) {
            [objects addObjectsFromArray:[self objectsOfClass:cls
                                          tableName:[NSString stringWithFormat:@"%@_%@", NSStringFromClass(cls), obj.name]
                                              where:nil]];
        }
    }];
    return objects;
}

- (NSArray *)objectsOfClass:(Class)cls
                  tableName:(NSString *)name
                      where:(NSString *)where {
    
    NSString *sql = [NSString stringWithFormat:@"select * from %@", name];
    if (where.length) {
        sql = [NSString stringWithFormat:@"select * from %@ where %@", name, where];
    }
    return [self objectsWithDictArray:[self querySql:sql] cls:cls];
}





#pragma mark - table methods
- (NSArray<HyDatabaseTable *> *)allTables {
    
    NSString *sqlString = [NSString stringWithFormat:@"select * from sqlite_master where type = 'table'"];
    /*
     {
         name = "HyTestObject_HyTestObject";
         rootpage = 2;
         sql = "CREATE TABLE HyTestObject_HyTestObject(age integer,core real,number text,name text, primary key(number))";
         "tbl_name" = "HyTestObject_HyTestObject";
         type = table;
     }
     */
    NSArray<NSDictionary *> *array = [self querySql:sqlString];
    NSMutableArray<HyDatabaseTable *> *mArray = @[].mutableCopy;
    for (NSDictionary *dict in array) {
        [mArray addObject:[self tableWithDic:dict]];
    }
    return mArray.copy;
}

- (NSArray<HyDatabaseTable *> *)tablesWithClass:(Class<HyDatabaseObjectProtocol>)cls {
    NSMutableArray *mArray = @[].mutableCopy;
    NSArray<HyDatabaseTable *> *array = [self allTables];
    for (HyDatabaseTable *table in array) {
        if (table.cls == cls) {
            [mArray addObject:table];
        }
    }
    return mArray.copy;
}

- (HyDatabaseTable *)tableWithName:(NSString *)name {
    if (!name.length) {
        return nil;
    }
    
    __block HyDatabaseTable *table = nil;
    [[self allTables] enumerateObjectsUsingBlock:^(HyDatabaseTable * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.name isEqualToString:name]) {
            table = obj;
            *stop = YES;
        }
    }];
    return table;
}

- (HyDatabaseTable *)tableWithDic:(NSDictionary *)dic {
    
    NSString *tableName = dic[@"tbl_name"];
    NSString *cls = [tableName componentsSeparatedByString:@"_"].firstObject;
    NSString *name = [tableName substringFromIndex:cls.length +1];
    
    NSString *createTableSql = dic[@"sql"];
    createTableSql = [createTableSql stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
    createTableSql = [createTableSql stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    createTableSql = [createTableSql stringByReplacingOccurrencesOfString:@"\n" withString:@""];
    createTableSql = [createTableSql stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    
    NSString *nameTypeStr = [createTableSql componentsSeparatedByString:@"("][1];
    NSArray *nameTypeArray = [nameTypeStr componentsSeparatedByString:@","];
    NSMutableArray *columnNameAarray = [NSMutableArray array];
    for (NSString *nameType in nameTypeArray) {
        if ([[nameType lowercaseString] containsString:@"primary"]) {
            continue;
        }
        NSString *nameType2 = [nameType stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" "]];
        NSString *name = [nameType2 componentsSeparatedByString:@" "].firstObject;
        [columnNameAarray addObject:name];
    }

    NSString *primarykey = [[createTableSql componentsSeparatedByString:@"("].lastObject componentsSeparatedByString:@")"].firstObject;

    HyDatabaseTable *table = HyDatabaseTable.new;
    table.name = name;
    table.cls = NSClassFromString(cls);
    table.primaryKey = primarykey;
    table.columnNameAarray = columnNameAarray.copy;
    
    return table;
}

- (BOOL)ifNeedsUptateTableWithClass:(Class<HyDatabaseObjectProtocol>)cls
                               name:(NSString *)name {
    
    HyDatabaseTable *table = [self tableWithName:name];
    if (!table) {
        return NO;
    }
    
    if (![table.primaryKey isEqualToString:[cls db_primaryKey]]) {
        return YES;
    }
    
    NSDictionary *ivarNameTypeDic = [self ivarNameTypeDicForClass:cls];
    NSArray *ivarNames = ivarNameTypeDic.allKeys;
    ivarNames = [ivarNames sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];

    NSArray *columnNameAarray =
    [table.columnNameAarray sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [obj1 compare:obj2];
    }];

    return ![ivarNames isEqualToArray:columnNameAarray];
}





#pragma mark - sqlite methods
- (BOOL)openDB {
    if (_db) { [self closeDB]; }
    return sqlite3_open(self.path.UTF8String, (sqlite3 **)&_db) == SQLITE_OK;
}

- (void)closeDB {
    sqlite3_close(_db);
}

- (BOOL)execSql:(NSString *)sql {
    
    if (!sql.length || ![self openDB]) {
        return NO;
    }
    
    BOOL result = sqlite3_exec(_db, sql.UTF8String, NULL, NULL, NULL) == SQLITE_OK;
    [self closeDB];
    
    return result;
}

- (NSArray<NSDictionary *> *)querySql:(NSString *)sql {
    
    if (!sql.length || ![self openDB]) {
        return nil;
    }
    
    sqlite3_stmt *ppStmt = NULL;
    if (sqlite3_prepare_v2(_db, sql.UTF8String, -1, (sqlite3_stmt **)&ppStmt, NULL) != SQLITE_OK) {
        NSLog(@"查询准备语句编译失败");
        sqlite3_finalize(ppStmt);
        [self closeDB];
        return nil;
    }
    
    NSMutableArray *rowDicArray = @[].mutableCopy;
    while (sqlite3_step(ppStmt) == SQLITE_ROW) {     // 移动指针
        NSMutableDictionary *rowDic = @{}.mutableCopy;
        for (int i = 0; i < sqlite3_column_count(ppStmt); ++i) {
            id value;
            switch (sqlite3_column_type(ppStmt, i)) {
                case SQLITE_INTEGER:
                    value = @(sqlite3_column_int(ppStmt, i));
                    break;
                case SQLITE_FLOAT:
                    value = @(sqlite3_column_double(ppStmt, i));
                    break;
                case SQLITE_BLOB:
                    value = CFBridgingRelease(sqlite3_column_blob(ppStmt, i));
                    break;
                case SQLITE_NULL:
                    value = @"";
                    break;
                case SQLITE3_TEXT:
                    value = [NSString stringWithUTF8String: (const char *)sqlite3_column_text(ppStmt, i)];
                    break;
                default:
                    break;
            }
            NSString *columnName = [NSString stringWithUTF8String:sqlite3_column_name(ppStmt, i)];
            [rowDic setObject:value forKey:columnName];
        }
        [rowDicArray addObject:rowDic.copy];
    }
    
    sqlite3_finalize(ppStmt);
    [self closeDB];
    
    return rowDicArray.copy;
}

- (BOOL)bindValueWithSqls:(NSArray<NSString *> *)sqls valuesArray:(NSArray<NSArray *> *)valuesArray {
    
    if (!sqls.count || !valuesArray.count || ![self openDB]) {
        return nil;
    }
    
   [self beginTransaction];
    
    sqlite3_stmt *ppStmt = NULL;
    for (NSInteger index = 0; index < MIN(sqls.count, valuesArray.count); ++index) {
        
        NSString *sql = sqls[index];
        NSArray *values = valuesArray[index];
        
        int rrd = sqlite3_prepare_v2(_db, sql.UTF8String, -1, (sqlite3_stmt **)&ppStmt, NULL);
        if (rrd != SQLITE_OK) {
            NSLog(@"准备语句编译失败");
            sqlite3_finalize(ppStmt);
            [self rollbackTransaction];
            [self closeDB];
            return NO;
        }
        
        int idx = 0;
        int min = (int)MIN(sqlite3_bind_parameter_count(ppStmt), values.count);
        while (idx < min) {
            [self bindValueWithStatement:ppStmt value:values[idx] column:++idx];
        }
        
        int result = sqlite3_step(ppStmt);
        if (result != SQLITE_DONE && result != SQLITE_OK) {
            sqlite3_finalize(ppStmt);
            [self rollbackTransaction];
            [self closeDB];
            return NO;
        }
    }
    
    sqlite3_finalize(ppStmt);
    [self commitTransaction];
    [self closeDB];
    
    return YES;
}

- (void)bindValueWithStatement:(sqlite3_stmt *)ppStmt
                         value:(id)value
                        column:(int)column {
    
    if (!value || [value isKindOfClass:NSNull.class]) {
        
        sqlite3_bind_null(ppStmt, column);
        
    } else if ([value isKindOfClass:NSData.class]) {
        
        const void *bytes = [value bytes];
        if (!bytes) { bytes = ""; }
        sqlite3_bind_blob(ppStmt, column, bytes, (int)[value length], SQLITE_STATIC);
        
    } else if ([value isKindOfClass:NSString.class]) {
        
        sqlite3_bind_text(ppStmt, column, [[value description] UTF8String], -1, SQLITE_STATIC);
        
    } else if ([value isKindOfClass:NSArray.class] ||
               [value isKindOfClass:NSDictionary.class]) {
        
        if ([value isKindOfClass:NSArray.class]) {
            NSMutableArray *mArray = @[].mutableCopy;
            for (id object in (NSArray *)value) {
                if ([object conformsToProtocol:@protocol(HyDatabaseObjectParserProtocol)] &&
                    [object respondsToSelector:@selector(db_objectToJSONString)]) {
                    id jsonString = [(id<HyDatabaseObjectParserProtocol>)object db_objectToJSONString];
                    if (jsonString) {
                        [mArray addObject:[NSString stringWithFormat:@"__hydbObject__%@__hydbObject__%@", NSStringFromClass([object class]), jsonString]];
                    }
                    value = mArray;
                }
            }
            
        } else if ([value isKindOfClass:NSDictionary.class]) {
            NSMutableDictionary *mDict = @{}.mutableCopy;
            [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                if ([obj conformsToProtocol:@protocol(HyDatabaseObjectParserProtocol)] &&
                    [obj respondsToSelector:@selector(db_objectToJSONString)]) {
                    Class cls = [obj class];
                    obj = [(id<HyDatabaseObjectParserProtocol>)obj db_objectToJSONString];
                    if (obj) {
                        obj = [NSString stringWithFormat:@"__hydbObject__%@__hydbObject__%@",NSStringFromClass([cls class]), obj];
                    }
                }
                [mDict setObject:obj forKey:key];
            }];
            value = mDict;
        }

        value = [[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:value options:NSJSONWritingPrettyPrinted error:nil] encoding:NSUTF8StringEncoding];
        
        sqlite3_bind_text(ppStmt, column, [[value description] UTF8String], -1, SQLITE_STATIC);
        
    } else if ([value isKindOfClass:NSNumber.class]) {
        
        if (strcmp([value objCType], @encode(char)) == 0) {
            sqlite3_bind_int(ppStmt, column, [value charValue]);
        } else if (strcmp([value objCType], @encode(unsigned char)) == 0) {
            sqlite3_bind_int(ppStmt, column, [value unsignedCharValue]);
        } else if (strcmp([value objCType], @encode(short)) == 0) {
            sqlite3_bind_int(ppStmt, column, [value shortValue]);
        } else if (strcmp([value objCType], @encode(unsigned short)) == 0) {
            sqlite3_bind_int(ppStmt, column, [value unsignedShortValue]);
        } else if (strcmp([value objCType], @encode(int)) == 0) {
            sqlite3_bind_int(ppStmt, column, [value intValue]);
        } else if (strcmp([value objCType], @encode(unsigned int)) == 0) {
            sqlite3_bind_int64(ppStmt, column, (long long)[value unsignedIntValue]);
        } else if (strcmp([value objCType], @encode(long)) == 0) {
            sqlite3_bind_int64(ppStmt, column, [value longValue]);
        } else if (strcmp([value objCType], @encode(unsigned long)) == 0) {
            sqlite3_bind_int64(ppStmt, column, (long long)[value unsignedLongValue]);
        } else if (strcmp([value objCType], @encode(long long)) == 0) {
            sqlite3_bind_int64(ppStmt, column, [value longLongValue]);
        } else if (strcmp([value objCType], @encode(unsigned long long)) == 0) {
            sqlite3_bind_int64(ppStmt, column, (long long)[value unsignedLongLongValue]);
        } else if (strcmp([value objCType], @encode(float)) == 0) {
            sqlite3_bind_double(ppStmt, column, [value floatValue]);
        } else if (strcmp([value objCType], @encode(double)) == 0) {
            sqlite3_bind_double(ppStmt, column, [value doubleValue]);
        } else if (strcmp([value objCType], @encode(BOOL)) == 0) {
            sqlite3_bind_int(ppStmt, column, ([value boolValue] ? 1 : 0));
        } else {
            sqlite3_bind_text(ppStmt, column, [[value description] UTF8String], -1, SQLITE_STATIC);
        }
        
    } else if ([value conformsToProtocol:@protocol(HyDatabaseObjectParserProtocol)] &&
               [value respondsToSelector:@selector(db_objectToJSONString)]) {
        
        value = [value db_objectToJSONString];
        sqlite3_bind_text(ppStmt, column, [[value description] UTF8String], -1, SQLITE_STATIC);
      
    } else {
        
        sqlite3_bind_text(ppStmt, column, [[value description] UTF8String], -1, SQLITE_STATIC);
    }
}

- (BOOL)dealSqls:(NSArray<NSString *> *)sqls {
    
    if (!sqls.count || ![self openDB]) {
        return NO;
    }
    
    [self beginTransaction];
    for (NSString *sql in sqls) {
        if (![self execSql:sql]) {
            [self rollbackTransaction];
            [self closeDB];
            return NO;
        }
    }
    [self commitTransaction];
    [self closeDB];
    
    return YES;
}

- (BOOL)beginTransaction {
    return sqlite3_exec(_db, @"begin transaction".UTF8String, NULL, NULL, NULL) == SQLITE_OK;
}

- (BOOL)commitTransaction {
    return sqlite3_exec(_db, @"commit transaction".UTF8String, NULL, NULL, NULL) == SQLITE_OK;
}

- (BOOL)rollbackTransaction {
    return sqlite3_exec(_db, @"rollback transaction".UTF8String, NULL, NULL, NULL) == SQLITE_OK;
}





#pragma mark - object method
- (NSDictionary<NSString *, NSString *> *)ivarNameTypeDicForClass:(Class<HyDatabaseObjectProtocol>)cls {

    NSMutableDictionary *nameTypeDic = [NSMutableDictionary dictionary];
    NSArray<NSString *> *ignoreProperties = nil;
    if ([cls respondsToSelector:@selector(db_ignoreProperties)]) {
        ignoreProperties = [cls db_ignoreProperties];
    }
    
    unsigned int outCount = 0;
    Ivar *varList = class_copyIvarList(cls, &outCount);
    for (int i = 0; i < outCount; i++) {
        Ivar ivar = varList[i];
        
        NSString *ivarName = [NSString stringWithUTF8String: ivar_getName(ivar)];
        if ([ivarName hasPrefix:@"_"]) {
            ivarName = [ivarName substringFromIndex:1];
        }
        if([ignoreProperties containsObject:ivarName]) {
            continue;
        }
        
        NSString *type = [NSString stringWithUTF8String:ivar_getTypeEncoding(ivar)];
        type = [type stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"@\""]];
        if ([NSClassFromString(type) conformsToProtocol:@protocol(HyDatabaseObjectParserProtocol)]) {
            type = [NSString stringWithFormat:@"NSObject_%@", type];
        }
        
        [nameTypeDic setValue:type forKey:ivarName];
    }
    
    return nameTypeDic;
}

- (NSDictionary<NSString *, NSString *> *)ivarNameSqliteTypeDicForClass:(Class<HyDatabaseObjectProtocol>)cls {
    
    NSMutableDictionary *ivarNameTypeDic = [self ivarNameTypeDicForClass:cls].mutableCopy;
    NSDictionary *typeDic = [self ocTypeToSqliteTypeDic];
    [ivarNameTypeDic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        if ([obj hasPrefix:@"NSObject_"]) {
            ivarNameTypeDic[key] = typeDic[@"NSObject"];
        } else {
            ivarNameTypeDic[key] = typeDic[obj];
        }
    }];
    return ivarNameTypeDic;
}

- (NSArray *)objectsWithDictArray:(NSArray<NSDictionary *> *)array
                              cls:(Class)cls {
    
    NSDictionary *nameTypeDic = [self ivarNameTypeDicForClass:cls];
    NSMutableArray *objects = @[].mutableCopy;
    for (NSDictionary *dic in array) {
        id object = [[cls alloc] init];
        [dic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            id value = obj;
            NSString *type = nameTypeDic[key];
            if ([type isEqualToString:@"NSArray"] ||
                [type isEqualToString:@"NSDictionary"]) {
                value = [NSJSONSerialization JSONObjectWithData:[obj dataUsingEncoding:NSUTF8StringEncoding] options:kNilOptions error:nil];
            } else if ([type isEqualToString:@"NSMutableArray"] ||
                       [type isEqualToString:@"NSMutableDictionary"]) {
                value = [NSJSONSerialization JSONObjectWithData:[obj dataUsingEncoding:NSUTF8StringEncoding] options:NSJSONReadingMutableContainers error:nil];
            } else if ([type isKindOfClass:NSNumber.class]) {
                NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
                formatter.numberStyle = NSNumberFormatterDecimalStyle;
                value = [formatter numberFromString:obj];
            } else if ([type isKindOfClass:NSDecimalNumber.class]) {
                value = [NSDecimalNumber decimalNumberWithString:obj];
            } else if ([type containsString:@"NSObject_"]) {
                type = [type substringFromIndex:@"NSObject_".length];
                Class objectCls = NSClassFromString(type);
                if ([objectCls conformsToProtocol:@protocol(HyDatabaseObjectParserProtocol)] &&
                    [objectCls respondsToSelector:@selector(db_objectWithJSONString:)]) {
                    value = [objectCls db_objectWithJSONString:value];
                }
            }

            if ([NSClassFromString(type) isKindOfClass:object_getClass(NSArray.class)]) {
                
                NSMutableArray *mArray = @[].mutableCopy;
                for (id object in (NSArray *)value) {
                    id val = object;
                    if ([val isKindOfClass:NSString.class] &&
                        [val hasPrefix:@"__hydbObject__"]) {
                        NSArray *coms = [val componentsSeparatedByString:@"__hydbObject__"];
                        Class objectCls = NSClassFromString(coms[1]);
                        if ([objectCls conformsToProtocol:@protocol(HyDatabaseObjectParserProtocol)] &&
                            [objectCls respondsToSelector:@selector(db_objectWithJSONString:)]) {
                            id v = [objectCls db_objectWithJSONString:[val componentsSeparatedByString:@"__hydbObject__"].lastObject];
                            if (v) {
                                val = v;
                            }
                        }
                    }
                    [mArray addObject:val];
                }
                
                if ([NSClassFromString(type) isMemberOfClass:object_getClass(NSArray.class)]) {
                    value = mArray.copy;
                } else {
                    value = mArray;
                }
                
            } else if ([NSClassFromString(type) isKindOfClass:object_getClass(NSDictionary.class)]) {
                
                NSMutableDictionary *mdict = @{}.mutableCopy;
                [(NSDictionary *)value enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                    id object = obj;
                    if ([obj isKindOfClass:NSString.class] && [(NSString *)obj hasPrefix:@"__hydbObject__"]) {
                        NSString *str = obj;
                        NSArray *coms = [str componentsSeparatedByString:@"__hydbObject__"];
                        Class objectCls = NSClassFromString(coms[1]);
                        if ([objectCls conformsToProtocol:@protocol(HyDatabaseObjectParserProtocol)] &&
                            [objectCls respondsToSelector:@selector(db_objectWithJSONString:)]) {
                            id v = [objectCls db_objectWithJSONString:coms.lastObject];
                            if (v) {
                                object = v;
                            }
                        }
                    }
                    [mdict setObject:object forKey:key];
                }];
            
                if ([NSClassFromString(type) isMemberOfClass:object_getClass(NSDictionary.class)]) {
                    value = mdict.copy;
                } else {
                    value = mdict;
                }
            }
            [object setValue:value forKeyPath:key];
        }];
        [objects addObject:object];
    }
    
    return objects.copy;
}


- (NSDictionary *)ocTypeToSqliteTypeDic {
    return @{
             @"d": @"real",  // double
             @"f": @"real", // float
             
             @"i": @"integer",    // int
             @"q": @"integer",   // long
             @"Q": @"integer",  // long long
             @"B": @"integer", // bool
                          
             @"NSData": @"blob",
             @"NSObject": @"text",
             @"NSString": @"text",
             
             @"NSDictionary": @"text",
             @"NSMutableDictionary": @"text",
             
             @"NSArray": @"text",
             @"NSMutableArray": @"text",
             
             @"NSNumber" : @"text",
             @"NSDecimalNumber" : @"text",
             };
}

@end
