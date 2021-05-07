//
//  AppDelegate.m
//  RTSPPlayerOSX
//
//  Created by Omar Zúñiga Lagunas on 01/02/16.
//  Copyright © 2016 omarzl. All rights reserved.
//

#import "AppDelegate.h"

NSString *const KEY_CAMERA_IP = @"cameraIpAddress";
NSString *const KEY_RTMP_URL = @"rtmpPushUrl";

@interface AppDelegate ()

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
}

- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}

- (void)restartApp {
    NSURL *url = [NSURL fileURLWithPath:NSBundle.mainBundle.resourcePath];
    NSString *path = [[[url URLByDeletingLastPathComponent] URLByDeletingLastPathComponent] absoluteString];
    
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/usr/bin/open";
    task.arguments = @[path];
    [task launch];
    exit(0);
}
@end
