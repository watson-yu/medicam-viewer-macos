//
//  ConnectionSettingsViewController.h
//  MediCamViewer
//
//  Created by watson on 2021/5/7.
//  Copyright © 2021 Fasmedo. All rights reserved.
//

#ifndef ConnSettingsViewController_h
#define ConnSettingsViewController_h

#import <Cocoa/Cocoa.h>

@interface ConnSettingsViewController : NSViewController

@property (weak) IBOutlet NSTextField *cameraIpAddress;
@property (weak) IBOutlet NSTextField *rtmpPushUrl;

@end

#endif /* ConnSettingsViewController_h */
