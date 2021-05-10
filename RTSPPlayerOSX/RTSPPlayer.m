#import "RTSPPlayer.h"
#import "Utilities.h"
#import "AudioStreamer.h"
#import "AppDelegate.h"

#ifndef AVCODEC_MAX_AUDIO_FRAME_SIZE
# define AVCODEC_MAX_AUDIO_FRAME_SIZE 192000 // 1 second of 48khz 32bit audio
#endif

@interface RTSPPlayer ()
@property (nonatomic, retain) AudioStreamer *audioController;
@end

@interface RTSPPlayer (private)
-(void)convertFrameToRGB;
-(NSImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height;
-(void)savePicture:(AVPicture)pFrame width:(int)width height:(int)height index:(int)iFrame;
-(void)setupScaler;

@end

@implementation RTSPPlayer

@synthesize audioController = _audioController;
@synthesize audioPacketQueue,audioPacketQueueSize;
@synthesize _audioStream,_audioCodecContext;
@synthesize emptyAudioBuffer;

@synthesize outputWidth, outputHeight;

- (void)setOutputWidth:(int)newValue
{
	if (outputWidth != newValue) {
        outputWidth = newValue;
        [self setupScaler];
    }
}

- (void)setOutputHeight:(int)newValue
{
	if (outputHeight != newValue) {
        outputHeight = newValue;
        [self setupScaler];
    }
}

- (NSImage *)currentImage
{
	if (!pFrame->data[0]) return nil;
	[self convertFrameToRGB];
	return [self imageFromAVPicture:picture width:outputWidth height:outputHeight];
}

- (double)duration
{
	return (double)pFormatCtx->duration / AV_TIME_BASE;
}

- (double)currentTime
{
    AVRational timeBase = pFormatCtx->streams[videoStream]->time_base;
    return packet.pts * (double)timeBase.num / timeBase.den;
}

- (int)sourceWidth
{
	return pCodecCtx->width;
}

- (int)sourceHeight
{
	return pCodecCtx->height;
}

- (void)init2
{
    isProcessing = NO;
    pts_start_live_timestamp_0 = 0;
    dts_start_live_timestamp_0 = 0;
    pts_start_live_timestamp_1 = 0;
    dts_start_live_timestamp_1 = 0;
    last_mux_dts_0_live = 0;
    last_mux_pts_0_live = 0;
    last_mux_dts_1_live = 0;
    last_mux_pts_1_live = 0;
}

- (id)initWithVideo:(NSString *)moviePath usesTcp:(BOOL)usesTcp
{
	if (!(self=[super init])) return nil;
 
    AVCodec         *pCodec;
		
    // Register all formats and codecs
    avcodec_register_all();
    av_register_all();
    avformat_network_init();
    
    // Set the RTSP Options
    AVDictionary *opts = 0;
    if (usesTcp) 
        av_dict_set(&opts, "rtsp_transport", "tcp", 0);

    
    if (avformat_open_input(&pFormatCtx, [moviePath UTF8String], NULL, &opts) !=0 ) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't open file\n");
        goto initError;
    }
    
    // Retrieve stream information
    if (avformat_find_stream_info(pFormatCtx,NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Couldn't find stream information\n");
        goto initError;
    }
    
    // Find the first video stream
    videoStream=-1;
    audioStream=-1;

    for (int i=0; i<pFormatCtx->nb_streams; i++) {
        if (pFormatCtx->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO) {
            NSLog(@"found video stream");
            videoStream=i;
        }
        
        if (pFormatCtx->streams[i]->codec->codec_type==AVMEDIA_TYPE_AUDIO) {
            audioStream=i;
            NSLog(@"found audio stream");
        }
    }
    
    if (videoStream==-1 && audioStream==-1) {
        goto initError;
    }

    // Get a pointer to the codec context for the video stream
    pCodecCtx = pFormatCtx->streams[videoStream]->codec;
    
    // Find the decoder for the video stream
    pCodec = avcodec_find_decoder(pCodecCtx->codec_id);
    if (pCodec == NULL) {
        av_log(NULL, AV_LOG_ERROR, "Unsupported codec!\n");
        goto initError;
    }
	
    // Open codec
    if (avcodec_open2(pCodecCtx, pCodec, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Cannot open video decoder\n");
        goto initError;
    }
    
    if (audioStream > -1 ) {
        NSLog(@"set up audiodecoder");
        [self setupAudioDecoder];
    }
	
    // Allocate video frame
    pFrame = av_frame_alloc();
			
	outputWidth = pCodecCtx->width;
	self.outputHeight = pCodecCtx->height;
    [self init2];
			
	return self;
	
initError:
	return nil;
}


- (void)setupScaler
{
	// Release old picture and scaler
	avpicture_free(&picture);
	sws_freeContext(img_convert_ctx);	
	
	// Allocate RGB picture
	avpicture_alloc(&picture, AV_PIX_FMT_RGB24, outputWidth, outputHeight);
	
	// Setup scaler
	static int sws_flags =  SWS_FAST_BILINEAR;
	img_convert_ctx = sws_getContext(pCodecCtx->width, 
									 pCodecCtx->height,
									 pCodecCtx->pix_fmt,
									 outputWidth, 
									 outputHeight,
                                     AV_PIX_FMT_RGB24,
									 sws_flags, NULL, NULL, NULL);
	
}

- (void)seekTime:(double)seconds
{
	AVRational timeBase = pFormatCtx->streams[videoStream]->time_base;
	int64_t targetFrame = (int64_t)((double)timeBase.den / timeBase.num * seconds);
	avformat_seek_file(pFormatCtx, videoStream, targetFrame, targetFrame, targetFrame, AVSEEK_FLAG_FRAME);
	avcodec_flush_buffers(pCodecCtx);
}

- (void)dealloc
{
	// Free scaler
	sws_freeContext(img_convert_ctx);	

	// Free RGB picture
	avpicture_free(&picture);
    
    // Free the packet that was allocated by av_read_frame
    av_free_packet(&packet);
	
    // Free the YUV frame
    av_free(pFrame);
	
    // Close the codec
    if (pCodecCtx) avcodec_close(pCodecCtx);
	
    // Close the video file
    if (pFormatCtx) avformat_close_input(&pFormatCtx);

    [_audioController _stopAudio];
    _audioController = nil;
	
    audioPacketQueue = nil;
    
    audioPacketQueueLock = nil;
    
}

-(int) initialize_outputfile:(AVFormatContext*)oc :(AVStream*) out_stream :(AVFormatContext*) ifmt_ctx :(const char*) dir :(int) flag
{
    // allocate memory block for saving context of output file
    int stream_mapping_size = pFormatCtx->nb_streams;
    int stream_index = 0;
    if (flag == 0)
        stream_mapping = (int*)av_mallocz_array(stream_mapping_size, sizeof(*stream_mapping));
    else
        stream_mapping_live = (int*)av_mallocz_array(stream_mapping_size, sizeof(*stream_mapping));


    // copy stream infomation from input to output
    for (int i = 0; i < ifmt_ctx->nb_streams; i++)
    {
        if (ifmt_ctx->streams[i]->codecpar->codec_type != AVMEDIA_TYPE_AUDIO &&
            ifmt_ctx->streams[i]->codecpar->codec_type != AVMEDIA_TYPE_VIDEO &&
            ifmt_ctx->streams[i]->codecpar->codec_type != AVMEDIA_TYPE_SUBTITLE) {
            if (flag == 0)
                stream_mapping[i] = -1;
            else
                stream_mapping_live[i] = -1;
            continue;
        }

        // Add new stream into output context
        if (flag == 0)
            stream_mapping[i] = stream_index++;
        else
            stream_mapping_live[i] = stream_index++;
        out_stream = avformat_new_stream(oc, NULL);
        avcodec_parameters_copy(out_stream->codecpar, ifmt_ctx->streams[i]->codecpar);
        out_stream->codecpar->codec_tag = 0;
    }

    // print input and output format info on the console
    av_dump_format(oc, 0, dir, 1);
    int ret = 0;
    // open file and initialize I/O context for output file
    ret = avio_open(&oc->pb, dir, AVIO_FLAG_WRITE);
    if (ret < 0) {
        return -1;
    }

    // write header in output file
    if (oc->pb)
    {
        ret = avformat_write_header(oc, NULL);
        if (ret < 0) {
            NSLog(@"write private data failed, return %d\r\n", ret);
        }
    }
    else {
        return -1;
    }

    return ret;
}

- (void) pushPacket
{
    if (! isProcessing) {
        [self pushPacketBackground:savedPacket0];
    }
}

- (int) pushPacketBackground:(AVPacket*)packet
{
    AVStream* out_stream = NULL;
    int ret = 0;

    if (!(ofmt_ctx && stream_mapping_live)) {
        
        NSUserDefaults *prefs = NSUserDefaults.standardUserDefaults;
        NSString *rtmpPushUrl = [prefs objectForKey:KEY_RTMP_URL];

        const char *url = [rtmpPushUrl cStringUsingEncoding:NSASCIIStringEncoding];

        ret = avformat_alloc_output_context2(&ofmt_ctx, NULL, "flv", url);
        if (ret < 0) {
            char a[64];
            char* err = av_make_error_string(a, 64, ret);
            NSLog(@"ERR::live_streaming: avformat_alloc_output_context2: %s\r\n", err);
            return ret;
        }
        ret = [self initialize_outputfile:ofmt_ctx :out_stream :pFormatCtx :url :1];
        if (ret < 0) {
            char a[64];
            char* err = av_make_error_string(a, 64, ret);
            NSLog(@"Initialization failed, return %s\r\n", err);
            //stop_live();
            return ret;
        }
    }
    
    AVStream* in_stream = pFormatCtx->streams[packet->stream_index];
    if (packet->stream_index >= pFormatCtx->nb_streams || !stream_mapping_live || stream_mapping_live[packet->stream_index] < 0) {
        NSLog(@"Something wrong\r\n");
        //stop_live();
        return -1;
    }
        
    packet->stream_index = stream_mapping_live[packet->stream_index];
    out_stream = ofmt_ctx->streams[packet->stream_index];

    if (packet->stream_index == 1) {
        if (pts_start_live_timestamp_1 == 0 || dts_start_live_timestamp_1 == 0) {
            // timestamp at recording starting
            pts_start_live_timestamp_1 = packet->pts;
            dts_start_live_timestamp_1 = packet->dts;
        }
        packet->pts -= pts_start_live_timestamp_1;
        packet->dts -= dts_start_live_timestamp_1;
        if (packet->pts == AV_NOPTS_VALUE || packet->pts < last_mux_pts_1_live || packet->dts < last_mux_dts_1_live) {
            int64_t duration = 0;
            if (packet->duration > 0) {
                // use duration from packet if it provide
                duration = packet->duration;
            } else {
                //, or calculate with frame rate and others
                duration = in_stream->time_base.den / in_stream->r_frame_rate.num * in_stream->r_frame_rate.den;
            }
            // translate timestamp when window was dragged or resized
            packet->pts = last_mux_pts_1_live + duration;
            packet->dts = last_mux_dts_1_live + duration;
        }
        // remember timestamp after translation for the next round
        last_mux_pts_1_live = packet->pts;
        last_mux_dts_1_live = packet->dts;
    } else if (packet->stream_index == 0) {
        if (pts_start_live_timestamp_0 == 0 || dts_start_live_timestamp_0 == 0) {
            // timestamp at recording starting
            pts_start_live_timestamp_0 = packet->pts;
            dts_start_live_timestamp_0 = packet->dts;
        }
        packet->pts -= pts_start_live_timestamp_0;
        packet->dts -= dts_start_live_timestamp_0;
        if (packet->pts == AV_NOPTS_VALUE || packet->pts < last_mux_pts_0_live || packet->dts < last_mux_dts_0_live) {
            int64_t duration = 0;
            if (packet->duration > 0) {
                // use duration from packet if it provide
                duration = packet->duration;
            } else {
                //, or calculate with frame rate and others
                if (in_stream->r_frame_rate.num > 0 && in_stream->r_frame_rate.den > 0)
                duration = in_stream->time_base.den / in_stream->r_frame_rate.num * in_stream->r_frame_rate.den;
            }
            // translate timestamp when window was dragged or resized
            packet->pts = last_mux_pts_0_live + duration;
            packet->dts = last_mux_dts_0_live + duration;
        }
        // remember timestamp after translation for the next round
        last_mux_pts_0_live = packet->pts;
        last_mux_dts_0_live = packet->dts;
    }

    packet->pts = av_rescale_q_rnd(packet->pts, in_stream->time_base, out_stream->time_base, (enum AVRounding)(AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX));
    packet->dts = av_rescale_q_rnd(packet->dts, in_stream->time_base, out_stream->time_base, (enum AVRounding)(AV_ROUND_NEAR_INF | AV_ROUND_PASS_MINMAX));
    packet->duration = av_rescale_q(packet->duration, in_stream->time_base, out_stream->time_base);
    packet->pos = -1;

    if ((packet->pts >= 0 && packet->dts >= 0)) {
        // write packet into file
        ret = av_interleaved_write_frame(ofmt_ctx, packet);
        if (ret < 0) {
            char a[64];
            char* err = av_make_error_string(a, 64, ret);
            NSLog(@"Error muxing packet: %s\r\n", err);
        }
    }
    if (packet) {
        av_packet_unref(packet);
        //av_packet_free(&packet);
    }

    return ret;
}

- (void)savePacketData:(AVPacket*)packet
{
    isProcessing = YES;
    AVPacket *newPacket = av_packet_alloc();
    av_packet_ref(newPacket, packet);
    savedPacket0 = newPacket;
    isProcessing = NO;
}

- (BOOL)stepFrame
{
	// AVPacket packet;
    int frameFinished=0;

    while (!frameFinished && av_read_frame(pFormatCtx, &packet) >=0 ) {
        [self savePacketData:&packet];
        
        // Is this a packet from the video stream?
        if(packet.stream_index==videoStream) {
            // Decode video frame
            avcodec_decode_video2(pCodecCtx, pFrame, &frameFinished, &packet);
        }
        
        if (packet.stream_index==audioStream) {
            // NSLog(@"audio stream");
            [audioPacketQueueLock lock];
            
            audioPacketQueueSize += packet.size;
            [audioPacketQueue addObject:[NSMutableData dataWithBytes:&packet length:sizeof(packet)]];
            
            [audioPacketQueueLock unlock];
            
            if (!primed) {
                primed=YES;
                [_audioController _startAudio];
            }
            
            if (emptyAudioBuffer) {
                [_audioController enqueueBuffer:emptyAudioBuffer];
            }
        }
	}
    
	return frameFinished!=0;
}

- (void)convertFrameToRGB
{
	sws_scale(img_convert_ctx,
              pFrame->data,
              pFrame->linesize,
              0,
              pCodecCtx->height,
              picture.data,
              picture.linesize);
}

- (NSImage *)imageFromAVPicture:(AVPicture)pict width:(int)width height:(int)height
{
	CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
	CFDataRef data = CFDataCreateWithBytesNoCopy(kCFAllocatorDefault, pict.data[0], pict.linesize[0]*height,kCFAllocatorNull);
	CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGImageRef cgImage = CGImageCreate(width, 
									   height, 
									   8, 
									   24, 
									   pict.linesize[0], 
									   colorSpace, 
									   bitmapInfo, 
									   provider, 
									   NULL, 
									   NO, 
									   kCGRenderingIntentDefault);
	CGColorSpaceRelease(colorSpace);
	NSImage *image = [[NSImage alloc] initWithCGImage:cgImage size:CGSizeMake(width, height)];
	
    CGImageRelease(cgImage);
	CGDataProviderRelease(provider);
	CFRelease(data);
	
	return image;
}

- (void)setupAudioDecoder
{    
    if (audioStream >= 0) {
        _audioBufferSize = AVCODEC_MAX_AUDIO_FRAME_SIZE;
        _audioBuffer = av_malloc(_audioBufferSize);
        _inBuffer = NO;
        
        _audioCodecContext = pFormatCtx->streams[audioStream]->codec;
        _audioStream = pFormatCtx->streams[audioStream];
        
        AVCodec *codec = avcodec_find_decoder(_audioCodecContext->codec_id);
        if (codec == NULL) {
            NSLog(@"Not found audio codec.");
            return;
        }
        
        if (avcodec_open2(_audioCodecContext, codec, NULL) < 0) {
            NSLog(@"Could not open audio codec.");
            return;
        }
        
        if (audioPacketQueue) {
            audioPacketQueue = nil;
        }        
        audioPacketQueue = [[NSMutableArray alloc] init];
        
        if (audioPacketQueueLock) {
            audioPacketQueueLock = nil;
        }
        audioPacketQueueLock = [[NSLock alloc] init];
        
        if (_audioController) {
            [_audioController _stopAudio];
            _audioController = nil;
        }
        _audioController = [[AudioStreamer alloc] initWithStreamer:self];
    } else {
        pFormatCtx->streams[audioStream]->discard = AVDISCARD_ALL;
        audioStream = -1;
    }
}

- (void)nextPacket
{
    _inBuffer = NO;
}

- (AVPacket*)readPacket
{
    if (_currentPacket.size > 0 || _inBuffer) return &_currentPacket;
    
    NSMutableData *packetData = [audioPacketQueue objectAtIndex:0];
    _packet = [packetData mutableBytes];
    
    if (_packet) {
        if (_packet->dts != AV_NOPTS_VALUE) {
            _packet->dts += av_rescale_q(0, AV_TIME_BASE_Q, _audioStream->time_base);
        }
        
        if (_packet->pts != AV_NOPTS_VALUE) {
            _packet->pts += av_rescale_q(0, AV_TIME_BASE_Q, _audioStream->time_base);
        }
        
        [audioPacketQueueLock lock];
        audioPacketQueueSize -= _packet->size;
        if ([audioPacketQueue count] > 0) {
            [audioPacketQueue removeObjectAtIndex:0];
        }
        [audioPacketQueueLock unlock];
        
        _currentPacket = *(_packet);
    }
    
    return &_currentPacket;   
}

- (void)closeAudio
{
    [_audioController _stopAudio];
    primed=NO;
}

- (void)savePPMPicture:(AVPicture)pict width:(int)width height:(int)height index:(int)iFrame
{
    FILE *pFile;
	NSString *fileName;
    int  y;
	
	fileName = [Utilities documentsPath:[NSString stringWithFormat:@"image%04d.ppm",iFrame]];
    // Open file
    NSLog(@"write image file: %@",fileName);
    pFile=fopen([fileName cStringUsingEncoding:NSASCIIStringEncoding], "wb");
    if (pFile == NULL) {
        return;
    }
	
    // Write header
    fprintf(pFile, "P6\n%d %d\n255\n", width, height);
	
    // Write pixel data
    for (y=0; y<height; y++) {
        fwrite(pict.data[0]+y*pict.linesize[0], 1, width*3, pFile);
    }
	
    // Close file
    fclose(pFile);
}

@end
