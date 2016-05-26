// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

#include "AudioEngine.h"
#include <AudioToolbox/AudioToolbox.h>
#include <AVFoundation/AVAudioSession.h>
#include <libkern/OSAtomic.h>
#include <mach/mach_time.h>

#define INVALID_BEAT_TIME DBL_MIN
#define INVALID_BPM DBL_MIN
#define INVALID_SAMPLE_POSITION DBL_MAX

static OSSpinLock lock;

/*
 * Structure that stores the data needed by the audio the main thread.
 */
typedef struct {
  UInt32 outputLatency; // Hardware output latency in HostTime
  Float64 resetToBeatTime;
  Float64 proposeBpm;
  Float64 quantum;
  BOOL isPlaying;
} EngineData;

/*
 * Structure that stores the data needed by the audio callback.
 */
typedef struct {
    ABLLinkRef ablLink;
    Float64 sampleRate; // Shared between threads. Only write when engine not running.
    Float64 secondsToHostTime; // Shared between threads. Only write when engine not running.
    Float64 metronomeSamplePosition; // Local to the audio thread.
    Float64 metronomeFrequency; // Local to the audio thread.
    EngineData sharedEngineData; // Shared between threads.
    EngineData lockfreeEngineData; // Copy of sharedEngineData local to the audio thread.
} LinkData;

/*
 * Pull data from the main thread to the audio thread if lock can be obtained.
 */
static void pullEngineData(EngineData* shared, EngineData* lockfree) {
    if (OSSpinLockTry(&lock)) {
        lockfree->outputLatency = shared->outputLatency;
        if (shared->resetToBeatTime != INVALID_BEAT_TIME) {
            lockfree->resetToBeatTime = shared->resetToBeatTime;
            shared->resetToBeatTime = INVALID_BEAT_TIME;
        }
        lockfree->proposeBpm = shared->proposeBpm;
        shared->proposeBpm = INVALID_BPM;
        lockfree->quantum = shared->quantum;
        lockfree->isPlaying = shared->isPlaying;
        OSSpinLockUnlock(&lock);
    }
}

/*
 * Subroutine to fill the audio-buffer with the metronome sound.
 */
static void fillBuffer(
    const UInt32 startFrame,
    const UInt32 inNumberFrames,
    AudioBufferList *buffers,
    Float64 *samplePosition,
    const Float64 frequency,
    const Float64 sampleRate) {

    for (UInt32 i = startFrame; i < inNumberFrames; ++i) {
        Float64 amp = 0.;
        // Simple cosine synth with a tick duration of 100ms.
        if (*samplePosition <= sampleRate / 10) {
            const Float64 osc = cos(2 * M_PI * (*samplePosition) / sampleRate * frequency);
            amp = osc * (1 - sin(*samplePosition * 5 * M_PI / sampleRate));
            (*samplePosition)++;
        }
        // Write metronome sound only to 1st channel and silence other channels
        SInt16 *bufData = (SInt16 *)(buffers->mBuffers[0].mData);
        bufData[i] = (SInt16)(32761. * amp);
        for (UInt32 j = 1; j < buffers->mNumberBuffers; ++j) {
            SInt16 *bufData = (SInt16 *)(buffers->mBuffers[j].mData);
            bufData[i] = 0;
        }
    }
}

/*
 * Create an audible click in the given audio buffers for every half beat on
 * the song timeline.
 */
static void clickInBuffer(
    const Float64 positionAtBufferBegin,
    const Float64 positionAtBufferEnd,
    const Float64 quantum,
    const UInt32 numSamples,
    AudioBufferList *buffers,
    const Float64 sampleRate,
    Float64 *metronomeSamplePosition,
    Float64 *metronomeFrequency) {

    static const Float64 beatsPerClick = 1.;

    const Float64 beatsInBuffer = positionAtBufferEnd - positionAtBufferBegin;
    const Float64 samplesPerBeat = numSamples / beatsInBuffer;
    Float64 clickAtPosition = positionAtBufferBegin - fmod(positionAtBufferBegin, beatsPerClick);

    while (clickAtPosition < positionAtBufferEnd) {
        const long offset = lround(samplesPerBeat * (clickAtPosition - positionAtBufferBegin));
        if (offset >= 0 && offset < (long)(numSamples)) {
            // Use a high pitch to emphasize the first beat of the quantum.
            *metronomeFrequency = fmod(clickAtPosition, quantum) == 0 ? 1567.98 : 1108.73;
            *metronomeSamplePosition = 0;
            fillBuffer((UInt32)offset, numSamples, buffers, metronomeSamplePosition, *metronomeFrequency, sampleRate);
        }
        clickAtPosition += beatsPerClick;
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

    LinkData *linkData = (LinkData *)inRefCon;
    EngineData* engineData = &linkData->lockfreeEngineData;

    pullEngineData(&linkData->sharedEngineData, engineData);

    const Float64 sampleRate = linkData->sampleRate;
    const Float64 secondsToHostTime = linkData->secondsToHostTime;

    fillBuffer(0, inNumberFrames, ioData,
      &linkData->metronomeSamplePosition, linkData->metronomeFrequency, sampleRate);

    // The mHostTime member of the timestamp represents the time at which the buffer is
    // delivered to the audio hardware. The output latency is the time from when the
    // buffer is delivered to the audio hardware to when the beginning of the buffer
    // starts reaching the output. We add those values to get the host time at which
    // the first sample of this buffer will be reaching the output.
    const UInt64 hostTimeAtBufferBegin = inTimeStamp->mHostTime + engineData->outputLatency;

    const ABLLinkTimelineRef timeline =
      ABLLinkCaptureAudioTimeline(linkData->ablLink);

    // Handle a timeline reset
    if (engineData->resetToBeatTime != INVALID_BEAT_TIME) {
        // Reset the beat timeline so that the requested beat time
        // occurs near the beginning of this buffer. The requested beat
        // time may not occur exactly at the beginning of this buffer
        // due to quantization, but it is guaranteed to occur within a
        // quantum after the beginning of this buffer. The returned beat
        // time is the actual beat time mapped to the beginning of this
        // buffer, which therefore may be less than the requested beat
        // time by up to a quantum.
        ABLLinkRequestBeatAtTime(
          timeline, engineData->resetToBeatTime, hostTimeAtBufferBegin, engineData->quantum);
        engineData->resetToBeatTime = INVALID_BEAT_TIME;
    }

    // Handle a tempo proposal
    if (engineData->proposeBpm != INVALID_BPM) {
        // Propose that the new tempo takes effect at the beginning of
        // this buffer.
        ABLLinkSetTempo(timeline, engineData->proposeBpm, hostTimeAtBufferBegin);
        engineData->proposeBpm = INVALID_BPM;
    }

    // Fill the buffer
    if (engineData->isPlaying) {
        // We use ABLLinkBeatTimeAtHostTime to query the beat time at the beginning of
        // the buffer.
        const Float64 beatTimeAtBufferBegin = ABLLinkBeatTimeAtHostTime(
            timeline, hostTimeAtBufferBegin, engineData->quantum);

        // To calculate the host time at buffer end we add the buffer duration to the host
        // time at buffer begin.
        const UInt64 bufferDurationHostTime =
            (UInt64)(secondsToHostTime * inNumberFrames / sampleRate);

        const Float64 beatTimeAtBufferEnd = ABLLinkBeatTimeAtHostTime(
            timeline, hostTimeAtBufferBegin + bufferDurationHostTime, engineData->quantum);

        // Add audible clicks to the buffer according to the portion of the song
        // timeline represented by this buffer.
        if (beatTimeAtBufferEnd >= 0.) {
            clickInBuffer(beatTimeAtBufferBegin, beatTimeAtBufferEnd,
                engineData->quantum, inNumberFrames, ioData, sampleRate,
                &linkData->metronomeSamplePosition, &linkData->metronomeFrequency);
        }
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
    return ABLLinkBeatTimeAtHostTime(
      ABLLinkCaptureAppTimeline(_linkData.ablLink),
      mach_absolute_time(),
      self.quantum);
}

- (Float64)quantum {
    const Float64 quantum = _linkData.sharedEngineData.quantum;
    return quantum;
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
- (id)initWithTempo:(Float64)bpm {
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
    _linkData.metronomeSamplePosition = INVALID_SAMPLE_POSITION;
    _linkData.metronomeFrequency = 0;
    _linkData.sharedEngineData.outputLatency =
        (UInt32)(_linkData.secondsToHostTime * [AVAudioSession sharedInstance].outputLatency);
    _linkData.sharedEngineData.resetToBeatTime = INVALID_BEAT_TIME;
    _linkData.sharedEngineData.proposeBpm = INVALID_BPM;
    _linkData.sharedEngineData.quantum = 4; // quantize to 4 beats
    _linkData.sharedEngineData.isPlaying = false;
    _linkData.lockfreeEngineData = _linkData.sharedEngineData;
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
