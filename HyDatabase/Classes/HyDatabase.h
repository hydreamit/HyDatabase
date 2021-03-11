//
//  HyDatabase.h
//  HyDatabase
//
//  Created by hydreamit on 2017/3/9.
//  Copyright © 2017 hydreamit. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN


@protocol HyDatabaseObjectProtocol <NSObject>
@required
+ (NSString *)db_primaryKey;
@optional
+ (NSArray<NSString *> *)db_ignoreProperties;
@end


// 属性是实体类 或 集合里含有实体类 要求实体类遵循此协议
@protocol HyDatabaseObjectParserProtocol <NSObject>
@required
+ (instancetype)db_objectWithJSONString:(NSString *)json;
- (NSString *)db_objectToJSONString;
@end



@interface HyDatabaseTable : NSObject
@property (nonatomic,assign,readonly) Class cls;
@property (nonatomic,copy,readonly) NSString *name;
@property (nonatomic,copy,readonly) NSString *primaryKey;
@property (nonatomic,strong,readonly) NSArray<NSString *> *columnNameAarray;
@end



@interface HyDatabase : NSObject

@property (nonatomic,copy,readonly) NSString *path;

+ (nullable instancetype)databaseWithName:(NSString *)name;
+ (nullable instancetype)databaseWithPath:(NSString *)path;

- (nullable NSArray<HyDatabaseTable *> *)allTables;
- (nullable NSArray<HyDatabaseTable *> *)tablesWithClass:(Class<HyDatabaseObjectProtocol>)cls;
- (nullable HyDatabaseTable *)tableWithName:(NSString *)name;

- (BOOL)createTableWithClass:(Class<HyDatabaseObjectProtocol>)cls;
- (BOOL)createTableWithClass:(Class<HyDatabaseObjectProtocol>)cls name:(NSString *)name;

- (BOOL)insertOrUpdateObject:(NSObject *)object;
- (BOOL)insertOrUpdateObject:(NSObject *)object into:(NSString *)name;
- (BOOL)insertOrUpdateObjects:(NSArray<NSObject *> *)objects into:(NSString *)name;
- (BOOL)insertOrUpdateObjectWithDict:(NSDictionary<NSString *, id> *)dict into:(NSString *)name;
- (BOOL)insertOrUpdateObjectWithDictArray:(NSArray<NSDictionary<NSString *, id> *> *)dictArray into:(NSString *)name;

- (BOOL)deleteObject:(NSObject *)object;
- (BOOL)deleteObject:(NSObject *)object from:(NSString *)name;
- (BOOL)deleteObjectFrom:(NSString *)name where:(NSString * _Nullable)where;

- (nullable NSArray *)objectsOfTableName:(NSString *)name;
- (nullable NSArray *)objectsOfTableName:(NSString *)name where:(NSString * _Nullable)where;
- (nullable NSArray *)objectsOfClass:(Class<HyDatabaseObjectProtocol>)cls;

@end



NS_ASSUME_NONNULL_END
