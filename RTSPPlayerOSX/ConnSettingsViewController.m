//
//  ConnectionSettingsViewController.m
//  MediCamViewer
//
//  Created by watson on 2021/5/7.
//  Copyright © 2021 omarzl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AppDelegate.h"
#import "ConnSettingsViewController.h"
#import "RTSPPlayer.h"

@interface ConnSettingsViewController()

@end

@implementation ConnSettingsViewController

- (void)viewDidLoad
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    self.cameraIpAddress.stringValue = [prefs objectForKey:KEY_CAMERA_IP];
    self.rtmpPushUrl.stringValue = [prefs objectForKey:KEY_RTMP_URL];
}

-(IBAction)save:(id)sender
{
    NSString *cameraIpAddress = [self.cameraIpAddress stringValue];
    NSString *rtmpPushUrl = [self.rtmpPushUrl stringValue];

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    [prefs setObject:cameraIpAddress forKey:KEY_CAMERA_IP];
    [prefs setObject:rtmpPushUrl forKey:KEY_RTMP_URL];
    [prefs synchronize];
    [self dismissViewController:self];
    
    AppDelegate *delegate = [NSApp delegate];
    [delegate restartApp];
}

-(IBAction)cancel:(id)sender
{
    [self dismissViewController:self];
}

@end
