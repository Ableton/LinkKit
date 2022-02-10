// Copyright: 2018, Ableton AG, Berlin. All rights reserved.

#include <AudioToolbox/AudioToolbox.h>
#include <AVFoundation/AVFoundation.h>
#include <libkern/OSAtomic.h>
#include <mach/mach_time.h>
#include "AudioEngine.h"
#include <os/lock.h>

#define INVALID_BEAT_TIME DBL_MIN
#define INVALID_BPM DBL_MIN

static struct os_unfair_lock_s lock;

/*
 * Structure that stores engine-related data that can be changed from
 * the main thread.
 */
typedef struct {
    UInt64 outputLatency; // Hardware output latency in HostTime
    Float64 resetToBeatTime;
    BOOL requestStart;
    BOOL requestStop;
    Float64 proposeBpm;
    Float64 quantum;
} EngineData;

/*
 * Structure that stores all data needed by the audio callback.
 */
typedef struct {
    ABLLinkRef ablLink;
    // Shared between threads. Only write when engine not running.
    Float64 sampleRate;
    // Shared between threads. Only write when engine not running.
    Float64 secondsToHostTime;
    // Shared between threads. Written by the main thread and only
    // read by the audio thread when doing so will not block.
    EngineData sharedEngineData;
    // Copy of sharedEngineData owned by audio thread.
    EngineData localEngineData;
    // Owned by audio thread
    UInt64 timeAtLastClick;
    // Owned by audio thread
    BOOL isPlaying;
} LinkData;

/*
 * Pull data from the main thread to the audio thread if lock can be
 * obtained. Otherwise, just use the local copy of the data.
 */
static void pullEngineData(LinkData* linkData) {
    // Always reset the signaling members to their default state
    linkData->localEngineData.resetToBeatTime = INVALID_BEAT_TIME;
    linkData->localEngineData.proposeBpm = INVALID_BPM;
    linkData->localEngineData.requestStart = NO;
    linkData->localEngineData.requestStop = NO;

    // Attempt to grab the lock guarding the shared engine data but
    // don't block if we can't get it.
    if (os_unfair_lock_trylock(&lock)) {
        // Copy non-signaling members to the local thread cache
        linkData->localEngineData.outputLatency =
          linkData->sharedEngineData.outputLatency;
        linkData->localEngineData.quantum = linkData->sharedEngineData.quantum;

        // Copy signaling members directly to the output and reset
        linkData->localEngineData.resetToBeatTime = linkData->sharedEngineData.resetToBeatTime;
        linkData->sharedEngineData.resetToBeatTime = INVALID_BEAT_TIME;

        linkData->localEngineData.requestStart = linkData->sharedEngineData.requestStart;
        linkData->sharedEngineData.requestStart = NO;

        linkData->localEngineData.requestStop = linkData->sharedEngineData.requestStop;
        linkData->sharedEngineData.requestStop = NO;

        linkData->localEngineData.proposeBpm = linkData->sharedEngineData.proposeBpm;
        linkData->sharedEngineData.proposeBpm = INVALID_BPM;
        os_unfair_lock_unlock(&lock);
    }

}
/*
 * Render a metronome sound into the given buffer according to the
 * given session state and quantum.
 */
static void renderMetronomeIntoBuffer(
    const ABLLinkSessionStateRef sessionState,
    const Float64 quantum,
    const UInt64 beginHostTime,
    const Float64 sampleRate,
    const Float64 secondsToHostTime,
    const UInt32 bufferSize,
    UInt64* timeAtLastClick,
    SInt16* buffer)
{
    // Metronome frequencies
    static const Float64 highTone = 1567.98;
    static const Float64 lowTone = 1108.73;
    // 100ms click duration
    static const Float64 clickDuration = 0.1;

    // The number of host ticks that elapse between samples
    const Float64 hostTicksPerSample = secondsToHostTime / sampleRate;

    for (UInt32 i = 0; i < bufferSize; ++i) {
        Float64 amplitude = 0.;
        // Compute the host time for this sample.
        const UInt64 hostTime = beginHostTime + llround(i * hostTicksPerSample);
        const UInt64 lastSampleHostTime = hostTime - llround(hostTicksPerSample);
        // Only make sound for positive beat magnitudes. Negative beat
        // magnitudes are count-in beats.
        if (ABLLinkBeatAtTime(sessionState, hostTime, quantum) >= 0.) {
            // If the phase wraps around between the last sample and the
            // current one with respect to a 1 beat quantum, then a click
            // should occur.
            if (ABLLinkPhaseAtTime(sessionState, hostTime, 1) <
                ABLLinkPhaseAtTime(sessionState, lastSampleHostTime, 1)) {
                *timeAtLastClick = hostTime;
            }

            const Float64 secondsAfterClick =
                (hostTime - *timeAtLastClick) / secondsToHostTime;

            // If we're within the click duration of the last beat, render
            // the click tone into this sample
            if (secondsAfterClick < clickDuration) {
                // If the phase of the last beat with respect to the current
                // quantum was zero, then it was at a quantum boundary and we
                // want to use the high tone. For other beats within the
                // quantum, use the low tone.
                const Float64 freq =
                    floor(ABLLinkPhaseAtTime(sessionState, hostTime, quantum)) == 0
                    ? highTone : lowTone;

                // Simple cosine synth
                amplitude =
                    cos(2 * M_PI * secondsAfterClick * freq) *
                    (1 - sin(5 * M_PI * secondsAfterClick));
            }
        }
        buffer[i] = (SInt16)(32761. * amplitude);
    }
}

/*
 * The audio callback. Query or reset the beat time and generate audible clicks
 * corresponding to beat time of the current buffer.
 */
static OSStatus audioCallback(
    void *inRefCon,
    AudioUnitRenderActionFlags *flags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData) {
#pragma unused(inBusNumber, flags)

    // First clear buffers
    for (UInt32 i = 0; i < ioData->mNumberBuffers; ++i) {
      memset(ioData->mBuffers[i].mData, 0, inNumberFrames * sizeof(SInt16));
    }

    LinkData *linkData = (LinkData *)inRefCon;

    // Get a copy of the current link session state.
    const ABLLinkSessionStateRef sessionState =
        ABLLinkCaptureAudioSessionState(linkData->ablLink);

    // Update the engine data.
    pullEngineData(linkData);

    // The mHostTime member of the timestamp represents the time at
    // which the buffer is delivered to the audio hardware. The output
    // latency is the time from when the buffer is delivered to the
    // audio hardware to when the beginning of the buffer starts
    // reaching the output. We add those values to get the host time
    // at which the first sample of this buffer will reach the output.
    const UInt64 hostTimeAtBufferBegin =
        inTimeStamp->mHostTime + linkData->localEngineData.outputLatency;

    if (linkData->localEngineData.requestStart && !ABLLinkIsPlaying(sessionState)) {
        // Request starting playback at the beginning of this buffer.
        ABLLinkSetIsPlaying(sessionState, YES, hostTimeAtBufferBegin);
    }

    if (linkData->localEngineData.requestStop && ABLLinkIsPlaying(sessionState)) {
        // Request stopping playback at the beginning of this buffer.
        ABLLinkSetIsPlaying(sessionState, NO, hostTimeAtBufferBegin);
    }

    if (!linkData->isPlaying && ABLLinkIsPlaying(sessionState)) {
        // Reset the session state's beat timeline so that the requested
        // beat time corresponds to the time the transport will start playing.
        // The returned beat time is the actual beat time mapped to the time
        // playback will start, which therefore may be less than the requested
        // beat time by up to a quantum.
        ABLLinkRequestBeatAtStartPlayingTime(sessionState, 0., linkData->localEngineData.quantum);
        linkData->isPlaying = YES;
    }
    else if(linkData->isPlaying && !ABLLinkIsPlaying(sessionState)) {
        linkData->isPlaying = NO;
    }

    // Handle a tempo proposal
    if (linkData->localEngineData.proposeBpm != INVALID_BPM) {
        // Propose that the new tempo takes effect at the beginning of
        // this buffer.
        ABLLinkSetTempo(sessionState, linkData->localEngineData.proposeBpm, hostTimeAtBufferBegin);
    }

    ABLLinkCommitAudioSessionState(linkData->ablLink, sessionState);

    // When playing, render the metronome sound
    if (linkData->isPlaying) {
        // Only render the metronome sound to the first channel. This
        // might help with source separate for timing analysis.
        renderMetronomeIntoBuffer(
            sessionState, linkData->localEngineData.quantum, hostTimeAtBufferBegin, linkData->sampleRate,
            linkData->secondsToHostTime, inNumberFrames, &linkData->timeAtLastClick,
            (SInt16*)ioData->mBuffers[0].mData);
    }

    return noErr;
}

# pragma mark - AudioEngine

@interface AudioEngine () {
    AudioUnit _ioUnit;
    LinkData _linkData;
}
@end

@implementation AudioEngine

# pragma mark - Transport
// Update _linkData.sharedEngineData so that the audio thread can receive the new values
// when calling pullEngineData

- (void)proposeTempo:(Float64)bpm {
    os_unfair_lock_lock(&lock);
    _linkData.sharedEngineData.proposeBpm = bpm;
    os_unfair_lock_unlock(&lock);
}

- (void)setQuantum:(Float64)quantum {
    os_unfair_lock_lock(&lock);
    _linkData.sharedEngineData.quantum = quantum;
    os_unfair_lock_unlock(&lock);
}

- (void)requestTransportStart {
    os_unfair_lock_lock(&lock);
    _linkData.sharedEngineData.requestStart = YES;
    os_unfair_lock_unlock(&lock);
}

- (void)requestTransportStop {
    os_unfair_lock_lock(&lock);
    _linkData.sharedEngineData.requestStop = YES;
    os_unfair_lock_unlock(&lock);
}

- (ABLLinkRef)linkRef {
    return _linkData.ablLink;
}

# pragma mark - Handle AVAudioSession changes
- (void)handleRouteChange:(NSNotification *)notification {
#pragma unused(notification)
    const UInt64 outputLatency =
        _linkData.secondsToHostTime * [AVAudioSession sharedInstance].outputLatency;
    os_unfair_lock_lock(&lock);
    _linkData.sharedEngineData.outputLatency = outputLatency;
    os_unfair_lock_unlock(&lock);
}

static void StreamFormatCallback(
    void *inRefCon,
    AudioUnit inUnit,
    AudioUnitPropertyID inID,
    AudioUnitScope inScope,
    AudioUnitElement inElement)
{
#pragma unused(inID)
    AudioEngine *engine = (__bridge AudioEngine *)inRefCon;

    if(inScope == kAudioUnitScope_Output && inElement == 0) {
        AudioStreamBasicDescription asbd;
        UInt32 dataSize = sizeof(asbd);
        OSStatus result = AudioUnitGetProperty(inUnit, kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output, 0, &asbd, &dataSize);
        NSCAssert2(
            result == noErr,
            @"Get Stream Format failed. Error code: %d '%.4s'",
            (int)result,
            (const char *)(&result));

        const Float64 oldSampleRate = engine->_linkData.sampleRate;
        if (oldSampleRate != asbd.mSampleRate) {
            [engine stop];
            [engine deallocAudioEngine];
            engine->_linkData.sampleRate = asbd.mSampleRate;
            [engine setupAudioEngine];
            [engine start];
        }
    }
}

# pragma mark - create and delete engine
- (instancetype)initWithTempo:(Float64)bpm {
    if ([super init]) {
        [self initLinkData:bpm];
        [self setupAudioEngine];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRouteChange:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:[AVAudioSession sharedInstance]];
    }
    return self;
}

_Pragma("clang diagnostic push")
_Pragma("clang diagnostic ignored \"-Wobjc-designated-initializers\"")
-(instancetype)init {
  NSAssert(NO, @"init is not the designated initializer for instances of AudioEngine.");
  return nil;
}
_Pragma("clang diagnostic pop")

- (void)dealloc {
    if (_ioUnit) {
        OSStatus result = AudioComponentInstanceDispose(_ioUnit);
        NSCAssert2(
            result == noErr,
            @"Could not dispose Audio Unit. Error code: %d '%.4s'",
            (int)result,
            (const char *)(&result));
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:@"AVAudioSessionRouteChangeNotification"
                                                  object:[AVAudioSession sharedInstance]];
    ABLLinkDelete(_linkData.ablLink);
}

# pragma mark - start and stop engine
- (void)start {
    NSError *error = nil;
    if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
        NSLog(@"Couldn't activate audio session: %@", error);
    }

    OSStatus result = AudioOutputUnitStart(_ioUnit);
    NSCAssert2(
        result == noErr,
        @"Could not start Audio Unit. Error code: %d '%.4s'",
        (int)result,
        (const char *)(&result));
}

- (void)stop {
    OSStatus result = AudioOutputUnitStop(_ioUnit);
    NSCAssert2(
        result == noErr,
        @"Could not stop Audio Unit. Error code: %d '%.4s'",
        (int)result,
        (const char *)(&result));

    NSError *error = nil;
    if (![[AVAudioSession sharedInstance] setActive:NO error:NULL]) {
        NSLog(@"Couldn't deactivate audio session: %@", error);
    }
}

- (void)initLinkData:(Float64)bpm {
    mach_timebase_info_data_t timeInfo;
    mach_timebase_info(&timeInfo);

    _linkData.ablLink = ABLLinkNew(bpm);
    _linkData.sampleRate = [AVAudioSession sharedInstance].sampleRate;
    _linkData.secondsToHostTime = (1.0e9 * timeInfo.denom) / (Float64)timeInfo.numer;
    _linkData.sharedEngineData.outputLatency =
        _linkData.secondsToHostTime * [AVAudioSession sharedInstance].outputLatency;
    _linkData.sharedEngineData.resetToBeatTime = INVALID_BEAT_TIME;
    _linkData.sharedEngineData.proposeBpm = INVALID_BPM;
    _linkData.sharedEngineData.requestStart = NO;
    _linkData.sharedEngineData.requestStop = NO;
    _linkData.sharedEngineData.quantum = 4; // quantize to 4 beats
    _linkData.localEngineData = _linkData.sharedEngineData;
    _linkData.timeAtLastClick = 0;
}

- (void)setupAudioEngine {
    // Start a playback audio session
    NSError *sessionError = NULL;
    BOOL success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                                    withOptions:AVAudioSessionCategoryOptionMixWithOthers
                                                          error:&sessionError];
    if(!success) {
        NSLog(@"Error setting category Audio Session: %@", sessionError.localizedDescription);
    }

    // Create Audio Unit
    AudioComponentDescription cd = {
        .componentManufacturer = kAudioUnitManufacturer_Apple,
        .componentType = kAudioUnitType_Output,
        .componentSubType = kAudioUnitSubType_RemoteIO,
        .componentFlags = 0,
        .componentFlagsMask = 0
    };

    AudioComponent component = AudioComponentFindNext(NULL, &cd);
    OSStatus result = AudioComponentInstanceNew(component, &_ioUnit);
    NSCAssert2(
        result == noErr,
        @"AudioComponentInstanceNew failed. Error code: %d '%.4s'",
        (int)result,
        (const char *)(&result));

    AudioStreamBasicDescription asbd = {
        .mFormatID          = kAudioFormatLinearPCM,
        .mFormatFlags       =
            kAudioFormatFlagIsSignedInteger |
            kAudioFormatFlagIsPacked |
            kAudioFormatFlagsNativeEndian |
            kAudioFormatFlagIsNonInterleaved,
        .mChannelsPerFrame  = 2,
        .mBytesPerPacket    = sizeof(SInt16),
        .mFramesPerPacket   = 1,
        .mBytesPerFrame     = sizeof(SInt16),
        .mBitsPerChannel    = 8 * sizeof(SInt16),
        .mSampleRate        = _linkData.sampleRate
    };

    result = AudioUnitSetProperty(
        _ioUnit,
        kAudioUnitProperty_StreamFormat,
        kAudioUnitScope_Input,
        0,
        &asbd,
        sizeof(asbd));
    NSCAssert2(
        result == noErr,
        @"Set Stream Format failed. Error code: %d '%.4s'",
        (int)result,
        (const char *)(&result));

    result = AudioUnitAddPropertyListener(
        _ioUnit,
        kAudioUnitProperty_StreamFormat,
        StreamFormatCallback,
        (__bridge void * _Nullable)(self));
    NSCAssert2(
        result == noErr,
        @"Adding Listener to Stream Format changes failed. Error code: %d '%.4s'",
        (int)result,
        (const char *)(&result));

    // Set Audio Callback
    AURenderCallbackStruct ioRemoteInput;
    ioRemoteInput.inputProc = audioCallback;
    ioRemoteInput.inputProcRefCon = &_linkData;

    result = AudioUnitSetProperty(
        _ioUnit,
        kAudioUnitProperty_SetRenderCallback,
        kAudioUnitScope_Input,
        0,
        &ioRemoteInput,
        sizeof(ioRemoteInput));
    NSCAssert2(
        result == noErr,
        @"Could not set Render Callback. Error code: %d '%.4s'",
        (int)result,
        (const char *)(&result));

    // Initialize Audio Unit
    result = AudioUnitInitialize(_ioUnit);
    NSCAssert2(
        result == noErr,
        @"Initializing Audio Unit failed. Error code: %d '%.4s'",
        (int)result,
        (const char *)(&result));
}

- (void)deallocAudioEngine {
    // Uninitialize Audio Unit
    OSStatus result = AudioUnitUninitialize(_ioUnit);
    NSCAssert2(
        result == noErr,
        @"Uninitializing Audio Unit failed. Error code: %d '%.4s'",
        (int)result,
        (const char *)(&result));
}

@end
