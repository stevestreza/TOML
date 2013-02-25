//
//  TOMLParser.m
//  toml
//
//  Created by Steve Streza on 2/24/13.
//  Copyright (c) 2013 Mustacheware. All rights reserved.
//

#import "TOMLParser.h"
#import <ISO8601DateFormatter/ISO8601DateFormatter.h>

#define TOMLLoggingEnabled 0

#if TOMLLoggingEnabled
#define TOMLLog(...) NSLog(__VA_ARGS__)
#else
#define TOMLLog(...)
#endif

@implementation TOMLParser {
	NSMutableDictionary *_parsedOutput;
	NSString *_string;
	NSScanner *_scanner;
	NSError *_error;
	
	NSCharacterSet *_whitespace;
	NSCharacterSet *_keySet;
	NSCharacterSet *_arraySet;
	NSCharacterSet *_numberSet;
	NSCharacterSet *_dateSet;
	NSCharacterSet *_dateOnlySet;
}

+(NSDictionary *)dictionaryWithContentsOfString:(NSString *)string error:(out NSError **)error{
	TOMLParser *parser = [[TOMLParser alloc] initWithString:string];
	return [parser parseWithError:error];
}

-(instancetype)initWithString:(NSString *)string{
	if(self = [self init]){
		_string = string;
		
		_whitespace = [NSCharacterSet characterSetWithCharactersInString:[NSString stringWithFormat:@"%c%c%c",0x09, 0x0A, 0x20]];
		_keySet = [[NSCharacterSet characterSetWithCharactersInString:@"="] invertedSet];
		_arraySet = [NSCharacterSet characterSetWithCharactersInString:@"[],"];
		_numberSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789."];
		_dateSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789.:+-,TWZ"];
		_dateOnlySet = [NSCharacterSet characterSetWithCharactersInString:@":+-,"];
	}
	return self;
}

-(NSDictionary *)parseWithError:(out NSError **)error{
	// preprocess by removing comments to simplify the structure
	NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\#.*$" options:NSRegularExpressionAnchorsMatchLines error:nil];
	NSString *noCommentsString = [regex stringByReplacingMatchesInString:_string options:0 range:NSMakeRange(0, _string.length) withTemplate:@""];
	
	_scanner = [[NSScanner alloc] initWithString:noCommentsString];
	[_scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@""]];
	
	_parsedOutput = [NSMutableDictionary dictionary];
	
	// state
	NSString *currentKeyGroup = nil;
	NSString *currentKey = nil;
	BOOL isProcessingValue = NO;
	
	@try{
		// parsing loop
		while(!_scanner.isAtEnd){
			@autoreleasepool {
				[_scanner scanCharactersFromSet:_whitespace intoString:nil];
				if(_scanner.isAtEnd) break;
				
				unichar character = [_scanner.string characterAtIndex:_scanner.scanLocation];
				TOMLLog(@"Character: %c", character);
				if(!isProcessingValue && character == '['){
					NSString *key = nil;
					_scanner.scanLocation++;
					if([_scanner scanUpToString:@"]" intoString:&key]){
						TOMLLog(@"Hash key: %@", key);
						currentKeyGroup = [key stringByTrimmingCharactersInSet:_whitespace];
					}
					_scanner.scanLocation++;
				}else if(character == '='){
					TOMLLog(@"Processing value");
					[_scanner scanCharactersFromSet:_whitespace intoString:nil];
					_scanner.scanLocation++;
					isProcessingValue = YES;
				}else{
					if(isProcessingValue){
						[self scannedValue:[self scanValue] forKey:currentKey inKeyGroup:currentKeyGroup];

						currentKey = nil;
						isProcessingValue = NO;
						if(_scanner.isAtEnd) break;
						_scanner.scanLocation++;
					}else{
						NSString *key = nil;
						if([_scanner scanCharactersFromSet:_keySet intoString:&key]){
							key = [key stringByTrimmingCharactersInSet:_whitespace];
							TOMLLog(@"Key: %@", key);
							currentKey = key;
						}
					}
				}
			}
		}
	}@catch (NSException *e) {
		NSLog(@"Exception: %@", e);
	}
	
	TOMLLog(@"Output: %@", _parsedOutput);
	
	if(_error){
		*error = _error;
		return nil;
	}else{
		return [_parsedOutput copy];
	}
}

-(void)scannedValue:(id)value forKey:(NSString *)key inKeyGroup:(NSString *)keyGroup{
	if(!value) return;
	if(!key || !key.length) return;
	
	NSString *fullPath;
	if(keyGroup && keyGroup.length){
		fullPath = [keyGroup stringByAppendingFormat:@".%@", key];
	}else{
		fullPath = key;
	}
	
	NSArray *keysInPath = [fullPath componentsSeparatedByString:@"."];
	[[keysInPath subarrayWithRange:NSMakeRange(0, keysInPath.count - 1)] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		NSString *keyPath = [[keysInPath subarrayWithRange:NSMakeRange(0, idx+1)] componentsJoinedByString:@"."];
		NSMutableDictionary *existingOutput = [_parsedOutput valueForKeyPath:keyPath];
		if(existingOutput){
			if(![existingOutput isKindOfClass:[NSDictionary class]]){
				TOMLLog(@"Fail here");
			}
		}else{
			existingOutput = [NSMutableDictionary dictionary];
			[_parsedOutput setValue:existingOutput forKeyPath:keyPath];
		}
	}];
	
	[_parsedOutput setValue:value forKeyPath:fullPath];
}

-(id)scanValue{
	NSUInteger startScanLocation = _scanner.scanLocation;
	id value = nil;
	
	[_scanner scanCharactersFromSet:_whitespace intoString:nil];
	NSString *dateString = nil;
	if([_scanner scanCharactersFromSet:_dateSet intoString:&dateString] && [dateString rangeOfCharacterFromSet:_dateOnlySet].location != NSNotFound){
		TOMLLog(@"Date! %@", dateString);
		value = [self parseDate:dateString];
	}else{
		[_scanner setScanLocation:startScanLocation];
	}
	
	if(!value){
		unichar character = [_scanner.string characterAtIndex:startScanLocation];
		if(character == '"'){
			value = [self scanStringValue];
		}else if(character == '['){
			TOMLLog(@"Processing array");
			value = [self scanArray];
		}else if([_numberSet characterIsMember:character]){
			value = [self scanNumberOrDate];
		}else if(character == 't' || character == 'f'){
			value = [self scanBoolean];
		}else{
			TOMLLog(@"Processing something else");
		}
	}
	
	return value;
}

-(NSString *)remainder{
	return [_scanner.string substringFromIndex:_scanner.scanLocation];
}

-(NSString *)unescapedString:(NSString *)value{
	value = [value stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
	value = [value stringByReplacingOccurrencesOfString:@"\\t" withString:@"\t"];
	value = [value stringByReplacingOccurrencesOfString:@"\\r" withString:@"\r"];
	value = [value stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""];
	value = [value stringByReplacingOccurrencesOfString:@"\\\\" withString:@"\\"];
	value = [value stringByReplacingOccurrencesOfString:@"\\0" withString:[NSString stringWithFormat:@"%c", 0x00]];
	return value;
}

-(NSString *)scanStringValue{
	_scanner.scanLocation++;
	NSMutableString *stringValue = [NSMutableString stringWithString:@"\""];
	NSString *stringFragment = nil;
	while([_scanner scanUpToString:@"\"" intoString:&stringFragment]){
		TOMLLog(@"Fragment %@", stringFragment);
		[stringValue appendString:stringFragment];
		if([_scanner.string characterAtIndex:_scanner.scanLocation - 1] != '\\'){
			break;
		}else{
			[stringValue appendString:@"\\\""];
		}
	}
	[stringValue appendString:@"\""];
	
	return [self parseString:stringValue];
}

-(NSArray *)scanArray{
	_scanner.scanLocation++;
//	NSUInteger scanStartLocation = _scanner.scanLocation;
	NSMutableArray *array = [NSMutableArray array];
	
	NSString *arrayValue = nil;
	id value = nil;
	while(YES){
		[_scanner scanUpToCharactersFromSet:_arraySet intoString:&arrayValue];
		TOMLLog(@"Array value %@", arrayValue);
		
		[_scanner scanCharactersFromSet:_whitespace intoString:nil];
		if(_scanner.isAtEnd) break;
		
		unichar nextCharacter = [_scanner.string characterAtIndex:_scanner.scanLocation];
		TOMLLog(@"Array next character: %c", nextCharacter);
		if(nextCharacter == '['){
			value = [self scanArray];
			[_scanner scanUpToCharactersFromSet:_arraySet intoString:nil];
		}else{
			value = [self parseValue:arrayValue];
		}
		_scanner.scanLocation++;
		
		if(value){
			[array addObject:value];
		}
		
		if(nextCharacter == ']'){
			break;
		}
	}
	
	return [array copy];
}

-(id)scanNumberOrDate{
	NSUInteger startScanLocation = _scanner.scanLocation;
	NSString *numberString = nil;
	if([_scanner scanCharactersFromSet:_dateSet intoString:&numberString] && [numberString rangeOfCharacterFromSet:_dateOnlySet].location != NSNotFound){
		return [self parseDate:numberString];
	}
	
	_scanner.scanLocation = startScanLocation;
	if([_scanner scanCharactersFromSet:_numberSet intoString:&numberString]){
		return [self parseNumber:numberString];
	}else{
		return nil;
	}
}

-(NSNumber *)scanBoolean{
	if([_scanner scanString:@"true" intoString:nil]){
		return @YES;
	}else if([_scanner scanString:@"false" intoString:nil]){
		return @NO;
	}else{
		return nil;
	}
}

-(NSString *)parseString:(NSString *)string{
	// string is in the format: "the string"
	// so prune the quotation marks
	string = [string substringWithRange:NSMakeRange(1, string.length - 2)];

	return [self unescapedString:string];
}

-(NSNumber *)parseNumber:(NSString *)string{
	if([string isEqualToString:@"true"]){
		return @YES;
	}else if([string isEqualToString:@"false"]){
		return @NO;
	}else{
		NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
		[formatter setAllowsFloats:YES];
		return [formatter numberFromString:string];
	}
}

-(NSDate *)parseDate:(NSString *)string{
	ISO8601DateFormatter *formatter = [[ISO8601DateFormatter alloc] init];
	return [formatter dateFromString:string];
}

-(id)parseNumberOrDate:(NSString *)string{
	if([string rangeOfCharacterFromSet:_dateOnlySet].location != NSNotFound){
		return [self parseDate:string];
	}else if([string rangeOfCharacterFromSet:_numberSet].location != NSNotFound){
		return [self parseNumber:string];
	}else{
		return nil;
	}
}

-(id)parseValue:(NSString *)string{
	string = [string stringByTrimmingCharactersInSet:_whitespace];
	unichar firstCharacter = [string characterAtIndex:0];
	if(firstCharacter == '"'){
		return [self parseString:string];
	}else if([_numberSet characterIsMember:firstCharacter]){
		return [self parseNumberOrDate:string];
	}else if(firstCharacter == 't' || firstCharacter == 'f'){
		return [self parseNumber:string];
	}else{
		return nil;
	}
}

-(NSDictionary *)parseErrorMetadata{
	NSUInteger byteLocation = _scanner.scanLocation;
	NSArray *lines = [[_scanner.string substringToIndex:byteLocation] componentsSeparatedByString:@"\n"];
	NSString *everythingButTheLastLine = [[lines subarrayWithRange:NSMakeRange(0, lines.count - 1)] componentsJoinedByString:@"\n"];
	
	NSUInteger numberOfLines = lines.count;
	NSUInteger characterOnLine = byteLocation - everythingButTheLastLine.length - 1;
	
	return @{@"line": @(numberOfLines), @"position": @(characterOnLine)};
}

-(void)failWithError:(NSError *)error{
	_error = error;
	@throw error;
}

-(void)failWithErrorMessage:(NSString *)message code:(NSInteger)code{
	NSMutableDictionary *dict = [[self parseErrorMetadata] mutableCopy];
	[dict setObject:message forKey:NSLocalizedDescriptionKey];
	[self failWithError:[NSError errorWithDomain:@"TOMLParserError" code:code userInfo:[dict copy]]];
}

@end
