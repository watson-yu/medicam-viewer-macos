//
//  ViewController.m
//  RTSPPlayerOSX
//
//  Created by Omar Zúñiga Lagunas on 01/02/16.
//  Copyright © 2016 omarzl. All rights reserved.
//

#import "ViewController.h"
#import "RTSPPlayer.h"
#import "AppDelegate.h"

#define LERP(A,B,C) ((A)*(1.0-C)+(B)*C)

@interface ViewController()

@property (nonatomic, retain) IBOutlet NSImageView *imageView;
@property (nonatomic, retain) RTSPPlayer *video;
@property (nonatomic, retain) NSTimer *nextFrameTimer;
@property (nonatomic, retain) NSTimer *pushFrameTimer;
@property (nonatomic) float lastFrameTime;

@end

@implementation ViewController

- (void)startTimers
{
    self.nextFrameTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30
                                                           target:self
                                                         selector:@selector(displayNextFrame:)
                                                         userInfo:nil
                                                          repeats:YES];

    self.pushFrameTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30
                                                           target:self
                                                         selector:@selector(pushFrame:)
                                                         userInfo:nil
                                                          repeats:YES];
}

- (void)stopTimers
{
    [self.nextFrameTimer invalidate];
    [self.pushFrameTimer invalidate];
}

- (NSString*)getCameraIpAddress
{
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    BOOL toSave = NO;
    
    NSString *cameraIpAddress = [prefs stringForKey:KEY_CAMERA_IP];
    if (!cameraIpAddress || [cameraIpAddress length] < 7) {
        cameraIpAddress = @"192.168.1.1";
        toSave = YES;
        [prefs setObject:cameraIpAddress forKey:KEY_CAMERA_IP];
    }
    
    NSString *rtmpPushUrl = [prefs stringForKey:KEY_RTMP_URL];
    if (!rtmpPushUrl || [rtmpPushUrl length] < 14) {
        rtmpPushUrl = @"rtpm://live.fasmedo.com/app/shuttle";
        //@"rtmp://23841437.fme.ustream.tv/ustreamVideo/23841437/MY37x2pST4cLTQUhtB46bhHKwJjBv5zw";
        toSave = YES;
        [prefs setObject:rtmpPushUrl forKey:KEY_RTMP_URL];
    }
    
    if (toSave) {
        [prefs synchronize];
    }
    return cameraIpAddress;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSString *cameraIpAddress = [self getCameraIpAddress];

    NSString *rtspUrl = [NSString stringWithFormat:@"rtsp://%@/h264?w=1280&h=720&fps=30", cameraIpAddress];
    
    self.lastFrameTime = -1;
    self.video = [[RTSPPlayer alloc] initWithVideo:rtspUrl usesTcp:NO];
    self.video.outputWidth=1280;
    self.video.outputHeight = 720;
    [self.video seekTime:0.0];

    [self startTimers];
}

-(void)displayNextFrame:(NSTimer *)timer
{
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    if (![self.video stepFrame]) {
        [timer invalidate];
        [self.video closeAudio];
        return;
    }
    self.imageView.image = self.video.currentImage;

    float frameTime = 1.0/([NSDate timeIntervalSinceReferenceDate]-startTime);
    if (self.lastFrameTime<0) {
        self.lastFrameTime = frameTime;
    } else {
        self.lastFrameTime = LERP(frameTime, self.lastFrameTime, 0.8);
    }
}

-(void)pushFrame:(NSTimer *)timer
{
    [self.video pushPacket];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

- (IBAction)startPreview:(id)sender
{
    [self startTimers];
}

- (IBAction)stopPreview:(id)sender
{
    [self stopTimers];
}

@end
