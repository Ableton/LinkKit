// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

#include "AudioEngine.h"
#include <AudioToolbox/AudioToolbox.h>
#include <AVFoundation/AVFoundation.h>
#include <libkern/OSAtomic.h>
#include <mach/mach_time.h>

#define INVALID_BEAT_TIME DBL_MIN
#define INVALID_BPM DBL_MIN

static OSSpinLock lock;

/*
 * Structure that stores engine-related data that can be changed from
 * the main thread.
 */
typedef struct {
  UInt32 outputLatency; // Hardware output latency in HostTime
  Float64 resetToBeatTime;
  Float64 proposeBpm;
  Float64 quantum;
  BOOL isPlaying;
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
} LinkData;

/*
 * Pull data from the main thread to the audio thread if lock can be
 * obtained. Otherwise, just use the local copy of the data.
 */
static void pullEngineData(LinkData* linkData, EngineData* output) {
    // Always reset the signaling members to their default state
    output->resetToBeatTime = INVALID_BEAT_TIME;
    output->proposeBpm = INVALID_BPM;

    // Attempt to grab the lock guarding the shared engine data but
    // don't block if we can't get it.
    if (OSSpinLockTry(&lock)) {
        // Copy non-signaling members to the local thread cache
        linkData->localEngineData.outputLatency =
          linkData->sharedEngineData.outputLatency;
        linkData->localEngineData.quantum = linkData->sharedEngineData.quantum;
        linkData->localEngineData.isPlaying = linkData->sharedEngineData.isPlaying;

        // Copy signaling members directly to the output and reset
        output->resetToBeatTime = linkData->sharedEngineData.resetToBeatTime;
        linkData->sharedEngineData.resetToBeatTime = INVALID_BEAT_TIME;

        output->proposeBpm = linkData->sharedEngineData.proposeBpm;
        linkData->sharedEngineData.proposeBpm = INVALID_BPM;

        OSSpinLockUnlock(&lock);
    }

    // Copy from the thread local copy to the output. This happens
    // whether or not we were able to grab the lock.
    output->outputLatency = linkData->localEngineData.outputLatency;
    output->quantum = linkData->localEngineData.quantum;
    output->isPlaying = linkData->localEngineData.isPlaying;
}
/*
 * Render a metronome sound into the given buffer according to the
 * given timeline and quantum.
 */
static void renderMetronomeIntoBuffer(
    const ABLLinkTimelineRef timeline,
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
        if (ABLLinkBeatAtTime(timeline, hostTime, quantum) >= 0.) {
            // If the phase wraps around between the last sample and the
            // current one with respect to a 1 beat quantum, then a click
            // should occur.
            if (ABLLinkPhaseAtTime(timeline, hostTime, 1) <
                ABLLinkPhaseAtTime(timeline, lastSampleHostTime, 1)) {
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
                    floor(ABLLinkPhaseAtTime(timeline, hostTime, quantum)) == 0
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

    // Get a copy of the current link timeline.
    const ABLLinkTimelineRef timeline =
        ABLLinkCaptureAudioTimeline(linkData->ablLink);

    // Get a copy of relevant engine parameters.
    EngineData engineData;
    pullEngineData(linkData, &engineData);

    // The mHostTime member of the timestamp represents the time at
    // which the buffer is delivered to the audio hardware. The output
    // latency is the time from when the buffer is delivered to the
    // audio hardware to when the beginning of the buffer starts
    // reaching the output. We add those values to get the host time
    // at which the first sample of this buffer will reach the output.
    const UInt64 hostTimeAtBufferBegin =
        inTimeStamp->mHostTime + engineData.outputLatency;

    // Handle a timeline reset
    if (engineData.resetToBeatTime != INVALID_BEAT_TIME) {
        // Reset the beat timeline so that the requested beat time
        // occurs near the beginning of this buffer. The requested beat
        // time may not occur exactly at the beginning of this buffer
        // due to quantization, but it is guaranteed to occur within a
        // quantum after the beginning of this buffer. The returned beat
        // time is the actual beat time mapped to the beginning of this
        // buffer, which therefore may be less than the requested beat
        // time by up to a quantum.
        ABLLinkRequestBeatAtTime(
            timeline, engineData.resetToBeatTime, hostTimeAtBufferBegin,
            engineData.quantum);
    }

    // Handle a tempo proposal
    if (engineData.proposeBpm != INVALID_BPM) {
        // Propose that the new tempo takes effect at the beginning of
        // this buffer.
        ABLLinkSetTempo(timeline, engineData.proposeBpm, hostTimeAtBufferBegin);
    }

    // When playing, render the metronome sound
    if (engineData.isPlaying) {
        // Only render the metronome sound to the first channel. This
        // might help with source separate for timing analysis.
        renderMetronomeIntoBuffer(
            timeline, engineData.quantum, hostTimeAtBufferBegin, linkData->sampleRate,
            linkData->secondsToHostTime, inNumberFrames, &linkData->timeAtLastClick,
            (SInt16*)ioData->mBuffers[0].mData);
    }

    ABLLinkCommitAudioTimeline(linkData->ablLink, timeline);

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
- (BOOL)isPlaying {
    return _linkData.sharedEngineData.isPlaying;
}

- (void)setIsPlaying:(BOOL)isPlaying {
    OSSpinLockLock(&lock);
    _linkData.sharedEngineData.isPlaying = isPlaying;
    if (isPlaying) {
        _linkData.sharedEngineData.resetToBeatTime = 0;
    }
    OSSpinLockUnlock(&lock);
}

- (Float64)bpm {
    return ABLLinkGetTempo(ABLLinkCaptureAppTimeline(_linkData.ablLink));
}

- (void)setBpm:(Float64)bpm {
    OSSpinLockLock(&lock);
    _linkData.sharedEngineData.proposeBpm = bpm;
    OSSpinLockUnlock(&lock);
}

- (Float64)beatTime {
    return ABLLinkBeatAtTime(
      ABLLinkCaptureAppTimeline(_linkData.ablLink),
      mach_absolute_time(),
      self.quantum);
}

- (Float64)quantum {
    return _linkData.sharedEngineData.quantum;
}

- (void)setQuantum:(Float64)quantum {
    OSSpinLockLock(&lock);
    _linkData.sharedEngineData.quantum = quantum;
    OSSpinLockUnlock(&lock);
}

- (BOOL)isLinkEnabled {
    return ABLLinkIsEnabled(_linkData.ablLink);
}

- (ABLLinkRef)linkRef {
    return _linkData.ablLink;
}

# pragma mark - Handle AVAudioSession changes
- (void)handleRouteChange:(NSNotification *)notification {
#pragma unused(notification)
    const UInt32 outputLatency =
        (UInt32)(_linkData.secondsToHostTime * [AVAudioSession sharedInstance].outputLatency);
    OSSpinLockLock(&lock);
    _linkData.sharedEngineData.outputLatency = outputLatency;
    OSSpinLockUnlock(&lock);
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

    lock = OS_SPINLOCK_INIT;
    _linkData.ablLink = ABLLinkNew(bpm);
    _linkData.sampleRate = [[AVAudioSession sharedInstance] sampleRate];
    _linkData.secondsToHostTime = (1.0e9 * timeInfo.denom) / (Float64)timeInfo.numer;
    _linkData.sharedEngineData.outputLatency =
        (UInt32)(_linkData.secondsToHostTime * [AVAudioSession sharedInstance].outputLatency);
    _linkData.sharedEngineData.resetToBeatTime = INVALID_BEAT_TIME;
    _linkData.sharedEngineData.proposeBpm = INVALID_BPM;
    _linkData.sharedEngineData.quantum = 4; // quantize to 4 beats
    _linkData.sharedEngineData.isPlaying = false;
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
        NSLog(@"Error setting category Audio Session: %@", [sessionError localizedDescription]);
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
