//
//  tomlTests.m
//  tomlTests
//
//  Created by Steve Streza on 2/24/13.
//  Copyright (c) 2013 Mustacheware. All rights reserved.
//

#import "tomlTests.h"
#import "TOMLParser.h"

@implementation tomlTests

- (void)setUp
{
    [super setUp];
    
    // Set-up code here.
}

- (void)tearDown
{
    // Tear-down code here.
    
    [super tearDown];
}

- (void)testExample
{
	NSString *tomlPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"example" ofType:@"toml"];
	NSData *tomlData = [[[NSFileManager alloc] init] contentsAtPath:tomlPath];
	NSString *toml = [[NSString alloc] initWithData:tomlData encoding:NSUTF8StringEncoding];

	STAssertNotNil(toml, @"No TOML data");
	
	NSError *error = nil;
	NSDictionary *dictionary = [TOMLParser dictionaryWithContentsOfString:toml error:&error];
	
	STAssertNil(error, @"Parser had error");
	STAssertNotNil(dictionary, @"Parser returned no dictionary");

#define KeyPathIs(_keyPath, _value) STAssertEqualObjects([dictionary valueForKeyPath:_keyPath], _value, _keyPath)
	
	KeyPathIs(@"title", @"TOML Example");
	KeyPathIs(@"owner.name", @"Tom Preston-Werner");
	KeyPathIs(@"owner.organization", @"GitHub");
	KeyPathIs(@"owner.bio", @"GitHub Cofounder & CEO\nLikes tater tots and beer.");
	STAssertTrue([dictionary[@"owner"][@"dob"] isKindOfClass:[NSDate class]], @"No date for owner.dob");
	
	KeyPathIs(@"database.server", @"192.168.1.1");
	KeyPathIs(@"database.ports", (@[ @8001, @8001, @8002 ]));
	KeyPathIs(@"database.connection_max", @5000);
	KeyPathIs(@"database.enabled", @YES);
	
	KeyPathIs(@"servers.alpha.ip", @"10.0.0.1");
	KeyPathIs(@"servers.alpha.dc", @"eqdc10");
	
	KeyPathIs(@"servers.beta.ip", @"10.0.0.2");
	KeyPathIs(@"servers.beta.dc", @"eqdc10");
	
	KeyPathIs(@"clients.data", ( @[ @[ @"gamma", @"delta" ], @[ @1, @2 ]] ));
}

@end
