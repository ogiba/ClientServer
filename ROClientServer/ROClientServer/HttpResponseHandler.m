//
//  HttpResponseHandler.m
//  ROClientServer
//
//  Created by Robert Ogiba on 28.08.2017.
//  Copyright © 2017 Robert Ogiba. All rights reserved.
//

#import "HttpResponseHandler.h"
#import "HttpServer.h"
//#import "AppTextFileResponse.h"

@implementation HttpResponseHandler

static NSMutableArray *registeredHandlers = nil;

+ (NSUInteger)priority {
    return 0;
}

+ (void)load {
    [HttpResponseHandler registerHandler:self];
}

+ (void)registerHandler:(Class)handlerClass {
    if (registeredHandlers == nil)
    {
        registeredHandlers = [[NSMutableArray alloc] init];
    }
    
    NSUInteger i;
    NSUInteger count = [registeredHandlers count];
    for (i = 0; i < count; i++)
    {
        if ([handlerClass priority] >= [[registeredHandlers objectAtIndex:i] priority])
        {
            break;
        }
    }
    [registeredHandlers insertObject:handlerClass atIndex:i];
}

+ (BOOL)canHandleRequest:(CFHTTPMessageRef)aRequest
                  method:(NSString *)requestMethod
                     url:(NSURL *)requestURL
            headerFields:(NSDictionary *)requestHeaderFields {
    return YES;
}

+ (Class)handlerClassForRequest:(CFHTTPMessageRef)aRequest
                         method:(NSString *)requestMethod
                            url:(NSURL *)requestURL
                   headerFields:(NSDictionary *)requestHeaderFields {
    for (Class handlerClass in registeredHandlers)
    {
        if ([handlerClass canHandleRequest:aRequest
                                    method:requestMethod
                                       url:requestURL
                              headerFields:requestHeaderFields])
        {
            return handlerClass;
        }
    }
    
    return nil;
}

+ (HttpResponseHandler *)handlerForRequest:(CFHTTPMessageRef)aRequest
                                fileHandle:(NSFileHandle *)requestFileHandle
                                    server:(HttpServer *)aServer {
    NSDictionary *requestHeaderFields =
    (__bridge NSDictionary *)CFHTTPMessageCopyAllHeaderFields(aRequest);
    NSURL *requestURL =
    (__bridge NSURL *)CFHTTPMessageCopyRequestURL(aRequest);
    NSString *method =
    (__bridge NSString *)CFHTTPMessageCopyRequestMethod(aRequest);
    
    Class classForRequest =
    [self handlerClassForRequest:aRequest
                          method:method
                             url:requestURL
                    headerFields:requestHeaderFields];
    
    HttpResponseHandler *handler =
    [[classForRequest alloc]
      initWithRequest:aRequest
      method:method
      url:requestURL
      headerFields:requestHeaderFields
      fileHandle:requestFileHandle
      server:aServer];
    
    return handler;
}

@end
