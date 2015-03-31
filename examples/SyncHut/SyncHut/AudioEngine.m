// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

#include "AudioEngine.h"
#include <AudioToolbox/AudioToolbox.h>
#include <AVFoundation/AVAudioSession.h>

/*
 * Create an audible click in the given audio buffers for every 6th tick of the
 * shared timeline. The integers on the shared timeline represent 24ths of a
 * beat, so the clicks happen on quarter beats. Only produce clicks for ticks
 * that occur within the given play range.
 */
static void clickOnBeatsInRange(ABLSyncPlayRangeRef range, AudioBufferList *buffers) {
    static const int16_t ticksPerClick = 6;

    const int64_t firstTick = ceil(ABLSyncSharedTimeAtPlayRangeStart(range));
    const int64_t ticksEnd = ceil(ABLSyncSharedTimeAtPlayRangeEnd(range));

    const int16_t toNextClick = ticksPerClick - (firstTick % ticksPerClick);

    for (int64_t nextClick = firstTick + (toNextClick % ticksPerClick);
        nextClick < ticksEnd;
        nextClick += ticksPerClick) {

        const UInt32 offset = ABLSyncSampleOffsetAtSharedTime(range, nextClick);
        for (UInt32 i = 0; i < buffers->mNumberBuffers; ++i) {
            SInt16 *bufData = buffers->mBuffers[i].mData;
            bufData[offset] = 8192; // Click!
        }
    }
}

/*
 * Structure that stores the data needed by the audio callback: an ABLSync
 * instance and the current sample rate.
 */
typedef struct {
    ABLSyncRef ablSync;
    Float64 sampleRate;
} SyncData;

/*
 * The audio callback. Query the set of play ranges for the given buffer and
 * generate an audible click corresponding to ticks on the shared timeline for
 * the valid ranges.
 */
static OSStatus audioCallback(
    void *inRefCon,
    AudioUnitRenderActionFlags *_flags,
    const AudioTimeStamp *inTimeStamp,
    UInt32 _inBusNumber,
    UInt32 inNumberFrames,
    AudioBufferList *ioData)
{
    for (UInt32 i = 0; i < ioData->mNumberBuffers; i++) {
        memset(ioData->mBuffers[i].mData, 0, inNumberFrames * sizeof(SInt16));
    }

    SyncData *syncData = (SyncData *)inRefCon;

    ABLSyncPlayRangeRef range = ABLSyncSynchronizeBuffer(
        syncData->ablSync,
        inTimeStamp,
        inNumberFrames,
        syncData->sampleRate);

    while (ABLSyncIsValidPlayRange(syncData->ablSync, range)) {
        clickOnBeatsInRange(range, ioData);
        range = ABLSyncNextPlayRange(range);
    }

    return noErr;
}

# pragma mark - AudioEngine

@interface AudioEngine () {
    AudioUnit _ioUnit;
    SyncData _syncData;
}
@end

@implementation AudioEngine

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
    ABLSyncDeleteSession(_syncData.ablSync);
}

- (ABLSyncRef)ablSync {
    return _syncData.ablSync;
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

    // Initialize the sync session with the current latency
    _syncData.ablSync = ABLSyncNewSession([[AVAudioSession sharedInstance] outputLatency]);
    _syncData.sampleRate = [[AVAudioSession sharedInstance] sampleRate];

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
