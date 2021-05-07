//
//  AppDelegate.h
//  RTSPPlayerOSX
//
//  Created by Omar Zúñiga Lagunas on 01/02/16.
//  Copyright © 2016 omarzl. All rights reserved.
//

#import <Cocoa/Cocoa.h>

FOUNDATION_EXPORT NSString *const KEY_CAMERA_IP;
FOUNDATION_EXPORT NSString *const KEY_RTMP_URL;

@interface AppDelegate : NSObject <NSApplicationDelegate>

- (void)restartApp;

@end

