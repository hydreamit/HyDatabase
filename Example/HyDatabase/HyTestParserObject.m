//
//  HyTestParserObject.m
//  HyDatabase
//
//  Created by hydreamit on 2017/3/10.
//  Copyright © 2017 hydreamit. All rights reserved.
//

#import "HyTestParserObject.h"
#import <YYModel/YYModel.h>

@implementation HyTestParserObject

- (NSString *)db_objectToJSONString {
    return [self yy_modelToJSONString];
}

+ (instancetype)db_objectWithJSONString:(NSString *)json {
    return [self yy_modelWithJSON:json];
}

@end
