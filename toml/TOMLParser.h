//
//  TOMLParser.h
//  toml
//
//  Created by Steve Streza on 2/24/13.
//  Copyright (c) 2013 Mustacheware. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TOMLParser : NSObject

+(NSDictionary *)dictionaryWithContentsOfString:(NSString *)string error:(out NSError **)error;

@end
