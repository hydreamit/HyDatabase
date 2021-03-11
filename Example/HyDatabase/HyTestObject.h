//
//  HyTestObject.h
//  HyDatabase
//
//  Created by hydreamit on 2017/3/6.
//  Copyright © 2017 hydreamit. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HyDatabase.h"
#import "HyTestParserObject.h"

NS_ASSUME_NONNULL_BEGIN

@interface HyTestObject : NSObject<HyDatabaseObjectProtocol>

@property (nonatomic,assign) NSInteger age;
@property (nonatomic,assign) CGFloat core;
@property (nonatomic,copy) NSString *name;

@property (nonatomic,assign) int xxgg;

@property (nonatomic,strong) NSNumber *number;
@property (nonatomic,strong) NSDecimalNumber *vser;

@property (nonatomic,strong) NSDictionary *dict;
@property (nonatomic,strong) NSMutableArray *mdict;

@property (nonatomic,strong) NSArray *array;
@property (nonatomic,strong) NSMutableArray *marray;

@property (nonatomic,strong) HyTestParserObject *objct;

@property (nonatomic,strong) NSArray<HyTestParserObject *> *objects;
@property (nonatomic,strong) NSDictionary<NSString *, HyTestParserObject *> *objectDict;

@property (nonatomic,strong) NSMutableArray<HyTestParserObject *> *mobjects;
@property (nonatomic,strong) NSMutableDictionary<NSString *, HyTestParserObject *> *mobjectDict;

@end

NS_ASSUME_NONNULL_END
