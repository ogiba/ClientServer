//
//  HttpResponseHandler.h
//  ROClientServer
//
//  Created by Robert Ogiba on 28.08.2017.
//  Copyright © 2017 Robert Ogiba. All rights reserved.
//

#import <Foundation/Foundation.h>

@class HttpServer;
@interface HttpResponseHandler : NSObject
{
    CFHTTPMessageRef request;
    NSString *requestMethod;
    NSDictionary *headerFields;
    NSFileHandle *fileHandle;
    HttpServer *server;
    NSURL *url;
}

+ (NSUInteger)priority;
+ (void)registerHandler:(Class)handlerClass;

+ (HttpResponseHandler *)handlerForRequest:(CFHTTPMessageRef)aRequest
                                fileHandle:(NSFileHandle *)requestFileHandle
                                    server:(HttpServer *)aServer;

- (id)initWithRequest:(CFHTTPMessageRef)aRequest
               method:(NSString *)method
                  url:(NSURL *)requestURL
         headerFields:(NSDictionary *)requestHeaderFields
           fileHandle:(NSFileHandle *)requestFileHandle
               server:(HttpServer *)aServer;
- (void)startResponse;
- (void)endResponse;

@end
