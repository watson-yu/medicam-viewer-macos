#import <Foundation/Foundation.h>
#import "libavformat/avformat.h"
#import "libavcodec/avcodec.h"
#import "libavformat/avio.h"
#import "libswscale/swscale.h"
#import "libavutil/mathematics.h"
#import <AudioToolbox/AudioQueue.h>
#import <AudioToolbox/AudioToolbox.h>

@interface RTSPPlayer : NSObject {
	AVFormatContext *pFormatCtx;
	AVCodecContext *pCodecCtx;
    AVFrame *pFrame;
    AVPacket packet;
	AVPicture picture;
	int videoStream;
    int audioStream;
	struct SwsContext *img_convert_ctx;
	int sourceWidth, sourceHeight;
	int outputWidth, outputHeight;
	NSImage *currentImage;
	double duration;
    double currentTime;
    NSLock *audioPacketQueueLock;
    AVCodecContext *_audioCodecContext;
    int16_t *_audioBuffer;
    int audioPacketQueueSize;
    NSMutableArray *audioPacketQueue;
    AVStream *_audioStream;
    NSUInteger _audioBufferSize;
    BOOL _inBuffer;
    AVPacket *_packet, _currentPacket;
    BOOL primed;
    
    AVPacket *savedPacket0;
   
    AVFormatContext *ofmt_ctx;
    AVStream* out_stream;
    BOOL isProcessing;
    int *stream_mapping, *stream_mapping_live;
    int64_t pts_start_live_timestamp_0, dts_start_live_timestamp_0;
    int64_t pts_start_live_timestamp_1, dts_start_live_timestamp_1;
    int64_t last_mux_pts_0_live, last_mux_dts_0_live;
    int64_t last_mux_pts_1_live, last_mux_dts_1_live;
}

/* Last decoded picture as UIImage */
@property (nonatomic, readonly) NSImage *currentImage;

/* Size of video frame */
@property (nonatomic, readonly) int sourceWidth, sourceHeight;

/* Output image size. Set to the source size by default. */
@property (nonatomic) int outputWidth, outputHeight;

/* Length of video in seconds */
@property (nonatomic, readonly) double duration;

/* Current time of video in seconds */
@property (nonatomic, readonly) double currentTime;

@property (nonatomic, retain) NSMutableArray *audioPacketQueue;
@property (nonatomic, assign) AVCodecContext *_audioCodecContext;
@property (nonatomic, assign) AudioQueueBufferRef emptyAudioBuffer;
@property (nonatomic, assign) int audioPacketQueueSize;
@property (nonatomic, assign) AVStream *_audioStream;

/* Initialize with movie at moviePath. Output dimensions are set to source dimensions. */
-(id)initWithVideo:(NSString *)moviePath usesTcp:(BOOL)usesTcp;

/* Read the next frame from the video stream. Returns false if no frame read (video over). */
-(BOOL)stepFrame;

/* Seek to closest keyframe near specified time */
-(void)seekTime:(double)seconds;

-(void)closeAudio;

- (AVPacket*)readPacket;
-(void)pushPacket;

@end
