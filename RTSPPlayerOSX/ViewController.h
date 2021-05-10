//
//  ViewController.h
//  RTSPPlayerOSX
//
//  Created by Omar Zúñiga Lagunas on 01/02/16.
//  Copyright © 2016 omarzl. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "GCDAsyncSocket.h"

#define PTP_PORT 15740

@interface ViewController : NSViewController <GCDAsyncSocketDelegate> {
    BOOL isRunningPreview;
    BOOL isPushing;
    BOOL socketConnected;
}

@end

