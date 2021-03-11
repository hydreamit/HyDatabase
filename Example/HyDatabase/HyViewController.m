//
//  HyViewController.m
//  HyDatabase
//
//  Created by hydreamit on 03/11/2017.
//  Copyright (c) 2017 hydreamit. All rights reserved.
//

#import "HyViewController.h"
#import "HyTestObject.h"
#import "HyDatabase.h"
#import "HyTestParserObject.h"


@interface HyViewController ()

@end

@implementation HyViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSMutableArray *mA = @[].mutableCopy;
    for (NSInteger idx = 0; idx < 10; ++idx) {
        
        HyTestObject *ob = HyTestObject.new;
        ob.age = 10;
        ob.core = 20.20;
        ob.name = @"xxdfssfsfefsefsfef";
        ob.xxgg = 12333;
        ob.dict = @{@"1" : @"2"};
        ob.mdict = @{@"2" : @"4"}.mutableCopy;
        ob.array = @[@"1", @"2"];
        ob.marray = @[@"2", @"4"].mutableCopy;
        ob.number = @(idx);
        ob.vser = [NSDecimalNumber decimalNumberWithString:@"100.230"];
        
        HyTestParserObject *ptest = HyTestParserObject.new;
        ptest.xxv = @(idx).stringValue;
        ob.objct = ptest;
        
        HyTestParserObject *ptesttt = HyTestParserObject.new;
        ptesttt.xxv = @(idx).stringValue;
        ob.objects = @[ptesttt];
        ob.mobjects = @[ptesttt].mutableCopy;
        
        HyTestParserObject *ptestttt = HyTestParserObject.new;
        ptestttt.xxv = @(idx).stringValue;
        ob.objectDict = @{@(idx).stringValue : ptestttt};
        ob.mobjectDict = @{@(idx).stringValue : ptestttt}.mutableCopy;
        
        [mA addObject:ob];
    }

    HyDatabase *db = [HyDatabase databaseWithName:@"HyCache"];
    [db createTableWithClass:HyTestObject.class];
    [db insertOrUpdateObjects:mA into:@"HyTestObject"];

    NSArray<HyTestObject *> *array = [db objectsOfTableName:NSStringFromClass(HyTestObject.class)];
    NSLog(@"%@", array);
}

//- (void)viewDidAppear:(BOOL)animated {
//    [super viewDidAppear:animated];
//
//    NSLog(@"%@", [[HyDatabase databaseWithName:@"HyCache"] objectsOfTableName:NSStringFromClass(HyTestObject.class)]);
//
//}
//

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
