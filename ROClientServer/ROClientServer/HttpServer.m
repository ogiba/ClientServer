//
//  HttpServer.m
//  ROClientServer
//
//  Created by Robert Ogiba on 28.08.2017.
//  Copyright © 2017 Robert Ogiba. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HttpServer.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import "HttpResponseHandler.h"

#define HTTP_SERVER_PORT 8080

NSString * const HTTPServerNotificationStateChanged = @"ServerNotificationStateChanged";

@interface HttpServer ()
@property (nonatomic, readwrite, retain) NSError *lastError;
@property (nonatomic, readwrite, assign) HTTPServerState state;
@end

@implementation HttpServer: NSObject

@synthesize lastError;
@synthesize state;

- (id)init
{
    self = [super init];
    if (self != nil)
    {
        self.state = SERVER_STATE_IDLE;
        responseHandlers = [[NSMutableSet alloc] init];
        incomingRequests =
        CFDictionaryCreateMutable(kCFAllocatorDefault,
                                  0,
                                  &kCFTypeDictionaryKeyCallBacks,
                                  &kCFTypeDictionaryValueCallBacks);
    }
    return self;
}

-(void)setState:(HTTPServerState)newState {
    if (state == newState)
    {
        return;
    }
    
    state = newState;
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:HTTPServerNotificationStateChanged
     object:self];
}

- (void)errorWithName:(NSString *)errorName
{
    self.lastError = [NSError
                      errorWithDomain:@"HTTPServerError"
                      code:0
                      userInfo:
                      [NSDictionary dictionaryWithObject:
                       NSLocalizedStringFromTable(
                                                  errorName,
                                                  @"",
                                                  @"HTTPServerErrors")
                                                  forKey:NSLocalizedDescriptionKey]];	
}

-(void)stop{
    self.state = SERVER_STATE_STOPPING;
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:NSFileHandleConnectionAcceptedNotification
     object:nil];
    
    [responseHandlers removeAllObjects];
    
    [listeningHandle closeFile];
    //[listeningHandle release];
    listeningHandle = nil;
    
//    for (NSFileHandle *incomingFileHandle in
//         [[(NSDictionary *)incomingRequests copy] autorelease])
//    {
//        [self stopReceivingForFileHandle:incomingFileHandle close:YES];
//    }
    
    if (socket)
    {
        CFSocketInvalidate(socket);
        CFRelease(socket);
        socket = nil;
    }
    
    self.state = SERVER_STATE_IDLE;
}

-(void)start{
    self.lastError = nil;
    self.state = SERVER_STATE_STARTING;
    
    socket = CFSocketCreate(kCFAllocatorDefault, PF_INET, SOCK_STREAM,
                            IPPROTO_TCP, 0, NULL, NULL);
    if (!socket)
    {
        [self errorWithName:@"Unable to create socket."];
        return;
    }
    
    int reuse = true;
    int fileDescriptor = CFSocketGetNative(socket);
    if (setsockopt(fileDescriptor, SOL_SOCKET, SO_REUSEADDR,
                   (void *)&reuse, sizeof(int)) != 0)
    {
        [self errorWithName:@"Unable to set socket options."];
        return;
    }
    
    struct sockaddr_in address;
    memset(&address, 0, sizeof(address));
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_ANY);
    address.sin_port = htons(HTTP_SERVER_PORT);
    CFDataRef addressData =
    CFDataCreate(NULL, (const UInt8 *)&address, sizeof(address));
    //[(id)addressData autorelease];
    
    if (CFSocketSetAddress(socket, addressData) != kCFSocketSuccess)
    {
        [self errorWithName:@"Unable to bind socket to address."];
        return;
    }
    
    listeningHandle = [[NSFileHandle alloc]
                       initWithFileDescriptor:fileDescriptor
                       closeOnDealloc:YES];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(receiveIncomingConnectionNotification:)
     name:NSFileHandleConnectionAcceptedNotification
     object:nil];
    [listeningHandle acceptConnectionInBackgroundAndNotify];
    
    self.state = SERVER_STATE_RUNNING;

}

- (void)receiveIncomingConnectionNotification:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSFileHandle *incomingFileHandle =
    [userInfo objectForKey:NSFileHandleNotificationFileHandleItem];
    
    if(incomingFileHandle)
    {
//        CFDictionaryAddValue(
//                             incomingRequests,
//                             incomingFileHandle,
//                             [(id)CFHTTPMessageCreateEmpty(kCFAllocatorDefault, TRUE) autorelease]);
//        
        [[NSNotificationCenter defaultCenter]
         addObserver:self
         selector:@selector(receiveIncomingDataNotification:)
         name:NSFileHandleDataAvailableNotification
         object:incomingFileHandle];
        
        [incomingFileHandle waitForDataInBackgroundAndNotify];
    }
    
    [listeningHandle acceptConnectionInBackgroundAndNotify];
}

- (void)receiveIncomingDataNotification:(NSNotification *)notification
{
    NSFileHandle *incomingFileHandle = [notification object];
    NSData *data = [incomingFileHandle availableData];
    
    if ([data length] == 0)
    {
        return;
    }
    
    CFHTTPMessageRef incomingRequest =
    (CFHTTPMessageRef)CFDictionaryGetValue(incomingRequests, nil);
    if (!incomingRequest)
    {
        return;
    }
    
    if (!CFHTTPMessageAppendBytes(
                                  incomingRequest,
                                  [data bytes],
                                  [data length]))
    {
        return;
    }
    
    if(CFHTTPMessageIsHeaderComplete(incomingRequest))
    {
        HttpResponseHandler *handler =
        [HttpResponseHandler
         handlerForRequest:incomingRequest
         fileHandle:incomingFileHandle
         server:self];
        
        [responseHandlers addObject:handler];
        
        [handler startResponse];	
        return;
    }
    
    [incomingFileHandle waitForDataInBackgroundAndNotify];
}


-(void)closeHandler:(HttpResponseHandler *)aHandler {
    [aHandler endResponse];
    [responseHandlers removeObject:aHandler];
}

@end
