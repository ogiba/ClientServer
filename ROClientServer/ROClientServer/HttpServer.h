//
//  HttpServer.h
//  ROClientServer
//
//  Created by Robert Ogiba on 28.08.2017.
//  Copyright © 2017 Robert Ogiba. All rights reserved.
//

#ifndef HttpServer_h
#define HttpServer_h

typedef enum
{
    SERVER_STATE_IDLE,
    SERVER_STATE_STARTING,
    SERVER_STATE_RUNNING,
    SERVER_STATE_STOPPING
} HTTPServerState;

@class HttpResponseHandler;

@interface HttpServer : NSObject
{
    NSError *lastError;
    NSFileHandle *listeningHandle;
    CFSocketRef socket;
    HTTPServerState state;
    CFMutableDictionaryRef incomingRequests;
    NSMutableSet *responseHandlers;
}

@property (nonatomic, readonly, retain) NSError *lastError;
@property (readonly, assign) HTTPServerState state;

+ (HttpServer *)sharedHTTPServer;

- (void)start;
- (void)stop;

- (void)closeHandler:(HttpResponseHandler *)aHandler;

@end

extern NSString * const HTTPServerNotificationStateChanged;

#endif /* HttpServer_h */
