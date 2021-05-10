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

- (void)startPreviewTimer
{
    if (self.nextFrameTimer) {
        [self.nextFrameTimer invalidate];
    }
    self.nextFrameTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30
                                                           target:self
                                                         selector:@selector(displayNextFrame:)
                                                         userInfo:nil
                                                          repeats:YES];
    isRunningPreview = YES;
}

- (void)startPushTimer
{
    if (self.pushFrameTimer) {
        [self.pushFrameTimer invalidate];
    }
    self.pushFrameTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30
                                                           target:self
                                                         selector:@selector(pushFrame:)
                                                         userInfo:nil
                                                          repeats:YES];
    isPushing = YES;
}

- (void)stopPushTimer
{
    if (self.pushFrameTimer) {
        [self.pushFrameTimer invalidate];
    }
    isPushing = NO;
}

- (void)stopPreviewTimer
{
    if (isPushing) {
        [self stopPushTimer];
    }
    if (self.nextFrameTimer) {
        [self.nextFrameTimer invalidate];
    }
    isRunningPreview = NO;
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
        rtmpPushUrl = @"rtmp://live.fasmedo.com/app/shuttle";
        //@"rtmp://23841437.fme.ustream.tv/ustreamVideo/23841437/MY37x2pST4cLTQUhtB46bhHKwJjBv5zw";
        toSave = YES;
        [prefs setObject:rtmpPushUrl forKey:KEY_RTMP_URL];
    }
    
    if (toSave) {
        [prefs synchronize];
    }
    return cameraIpAddress;
}

- (void)connectCamera:(NSString *)cameraIpAddress
{
    NSString *rtspUrl = [NSString stringWithFormat:@"rtsp://%@/h264?w=1280&h=720&fps=30", cameraIpAddress];
    
    self.lastFrameTime = -1;
    self.video = [[RTSPPlayer alloc] initWithVideo:rtspUrl usesTcp:NO];
    self.video.outputWidth=1280;
    self.video.outputHeight = 720;
    [self.video seekTime:0.0];

    [self startPreviewTimer];
    //[self startPushTimer];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    isRunningPreview = NO;
    isPushing = NO;
    
    NSString *cameraIpAddress = [self getCameraIpAddress];
    if (cameraIpAddress && [cameraIpAddress length] > 7) {
        socketConnected = NO;
        [self checkSocket:cameraIpAddress];
    }
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

- (void)checkSocket:(NSString*)ipAddress
{
    NSError *error;
    GCDAsyncSocket *asyncSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    socketConnected = NO;
    [asyncSocket connectToHost:ipAddress onPort:PTP_PORT withTimeout:6.8 error:&error];
}

- (void)socket:(GCDAsyncSocket *)sock didConnectToHost:(NSString *)host port:(UInt16)port
{
    NSLog(@"Connected");
    socketConnected = YES;
    [self connectCamera:host];
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(nullable NSError *)err
{
    if (socketConnected) {
        // Disconnect after checked successfully, normal case
    } else {
        // handle error
        NSLog(@"Disonnected");
        [self performSegueWithIdentifier:@"ConnectionSettingsSegue" sender:self];

    }
}


- (IBAction)startPreview:(id)sender
{
    [self startPreviewTimer];
}

- (IBAction)stopPreview:(id)sender
{
    if (isPushing) {
        [self stopPushTimer];
    }
    [self stopPreviewTimer];
}

- (IBAction)startPushing:(id)sender
{
    if (! isRunningPreview) {
        [self startPreviewTimer];
    }
    [self startPushTimer];
}

- (IBAction)stopPushing:(id)sender
{
    [self stopPushTimer];
}

@end
