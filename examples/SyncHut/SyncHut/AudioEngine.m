// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

#include "AudioEngine.h"
#include "ABLSync.h"
#include <AudioToolbox/AudioToolbox.h>
#include <AVFoundation/AVAudioSession.h>
#include <mach/mach_time.h>


/*
 * Calculate the effective Beats Per Minute value for a range of beat values
 * over the given number of samples at the given sample rate.
 */
static Float64 bpmInRange(
    const Float64 fromBeat,
    const Float64 toBeat,
    const UInt32 numSamples,
    const Float64 sampleRate) {
    return (toBeat - fromBeat) * sampleRate * 60 / numSamples;
}

/*
 * Create an audible click in the given audio buffers for every half beat on
 * the song timeline.
 */
static void clickInBuffer(
    const Float64 positionAtBufferBegin,
    const Float64 positionAtBufferEnd,
    const UInt32 numSamples,
    AudioBufferList *buffers) {

    static const Float64 beatsPerClick = 0.5;

    const Float64 beatsInBuffer = positionAtBufferEnd - positionAtBufferBegin;
    const Float64 samplesPerBeat = numSamples / beatsInBuffer;

    Float64 clickAtPosition = positionAtBufferBegin - fmod(positionAtBufferBegin, beatsPerClick);

    while (clickAtPosition < positionAtBufferEnd) {
        const long offset = lround(samplesPerBeat * (clickAtPosition - positionAtBufferBegin));
        if (offset >= 0 && offset < (long)(numSamples)) {
            for (UInt32 i = 0; i < buffers->mNumberBuffers; ++i) {
                SInt16 *bufData = buffers->mBuffers[i].mData;
                if (fmod(clickAtPosition, 4) == 0) {
                  bufData[offset] = 16384; // Click! Emphasize first Beat of 4/4 Bar
                }
                else {
                  bufData[offset] = 8192; // Click!
                }
            }
        }
        clickAtPosition += beatsPerClick;
    }
}

/*
 * Structure that stores the data needed by the audio callback
 */
typedef struct {
    ABLSyncRef ablSync;
    Float64 sampleRate;
    BOOL isPlaying;
    Float64 bpm;
    Float64 lastBeatTime;
    Float64 startBeatTime;
    Float64 quantum;
    Float64 secondsToHostTime;
    UInt64 outputLatency; // hardware output latency in HostTime
} SyncData;

/*
 * The audio callback. Query the set of play ranges for the given buffer and
 * generate an audible click corresponding to ticks on the shared timeline for
 * the valid ranges.
 */
static OSStatus audioCallback(
    void *inRefCon,
    AudioUnitRenderActionFlags *flags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData) {
#pragma unused(inBusNumber, flags)
    for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
        memset(ioData->mBuffers[i].mData, 0, inNumberFrames * sizeof(SInt16));
    }

    SyncData *syncData = (SyncData *)inRefCon;

    const Float64 beatTimeAtBufferBegin = syncData->lastBeatTime;

    const UInt64 bufferDurationHostTime =
        (UInt64)(syncData->secondsToHostTime * inNumberFrames / syncData->sampleRate);

    // Find out what the beat time should be at the end of this
    // buffer. The mHostTime member of the timestamp represents the
    // time at which the buffer is delivered to the audio
    // hardware. The output latency is the time from when the
    // buffer is delivered to the audio hardware to when the beginning
    // of the buffer starts reaching the output. We add these
    // values with the buffer duration to get the host time at which
    // the end of this buffer will be reaching the output.
    const Float64 beatTimeAtBufferEnd = ABLSyncBeatTimeAtHostTime(
        syncData->ablSync,
        inTimeStamp->mHostTime + bufferDurationHostTime + syncData->outputLatency);

    if (syncData->isPlaying) {
        // Always re-quantize the start time in order to support changes to the
        // shared quantization grid while playing
        syncData->startBeatTime =
            ABLSyncQuantizeBeatTime(syncData->ablSync, syncData->quantum, syncData->startBeatTime);
        // Calculate song position values for the buffer. Song position is
        // considered to be the number of beats since starting play.
        const Float64 beginSongPosition = beatTimeAtBufferBegin - syncData->startBeatTime;
        const Float64 endSongPosition = beatTimeAtBufferEnd - syncData->startBeatTime;
        // Add audible clicks to the buffer according to the portion of the song
        // timeline represented by this buffer.
        clickInBuffer(beginSongPosition, endSongPosition, inNumberFrames, ioData);
    }
    else {
        // When not playing, move the start time to the end of every buffer
        // so that it's already correct if we start playing in the next buffer.
        syncData->startBeatTime = beatTimeAtBufferEnd;
    }

    syncData->lastBeatTime = beatTimeAtBufferEnd;
    syncData->bpm = bpmInRange(beatTimeAtBufferBegin, beatTimeAtBufferEnd, inNumberFrames, syncData->sampleRate);

    return noErr;
}

# pragma mark - AudioEngine

@interface AudioEngine () {
    AudioUnit _ioUnit;
    SyncData _syncData;
}
@end

@implementation AudioEngine

# pragma mark - Transport
- (BOOL)isPlaying {
    return _syncData.isPlaying;
}

- (void)setIsPlaying:(BOOL)isPlaying {
    _syncData.isPlaying = isPlaying;
}

- (Float64)bpm {
    return _syncData.bpm;
}

- (void)setBpm:(Float64)bpm {
    ABLSyncProposeTempo(_syncData.ablSync, bpm, _syncData.lastBeatTime);
}

- (Float64)beatTime {
    return _syncData.lastBeatTime;
}

- (Float64)quantum {
    return _syncData.quantum;
}

- (void)setQuantum:(Float64)quantum {
    _syncData.quantum = quantum;
}

- (BOOL)isSyncEnabled {
    return ABLSyncIsEnabled(_syncData.ablSync);
}

- (void)setIsSyncEnabled:(BOOL)isEnabled {
    ABLSyncEnable(_syncData.ablSync, isEnabled);
}

# pragma mark - create and delete engine
- (id)init {
    if ([super init]) {
        [self setupAudioEngine];
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
    ABLSyncDelete(_syncData.ablSync);
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

- (void)setupAudioEngine {
    // Start a playback audio session
    NSError *sessionError = NULL;
    BOOL success = [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback
                                                          error:&sessionError];
    if(!success) {
        NSLog(@"Error setting category Audio Session: %@", [sessionError localizedDescription]);
    }

    mach_timebase_info_data_t timeInfo;
    mach_timebase_info(&timeInfo);

    // Initialize the sync session with the current latency
    _syncData.sampleRate = [[AVAudioSession sharedInstance] sampleRate];
    _syncData.isPlaying = false;
    _syncData.bpm = 120.0;
    _syncData.lastBeatTime = 0;
    _syncData.startBeatTime = 0;
    _syncData.quantum = 4; // Sync to whole beats
    _syncData.secondsToHostTime = (1.0e9 * timeInfo.denom) / (Float64)timeInfo.numer;
    _syncData.outputLatency = (UInt64)(_syncData.secondsToHostTime * [AVAudioSession sharedInstance].outputLatency);
    _syncData.ablSync = ABLSyncNew(_syncData.bpm);

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
        .mSampleRate        = _syncData.sampleRate
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

    // Set Audio Callback
    AURenderCallbackStruct ioRemoteInput;
    ioRemoteInput.inputProc = audioCallback;
    ioRemoteInput.inputProcRefCon = &_syncData;

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

@end
