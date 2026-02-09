// Copyright: 2018, Ableton AG, Berlin. All rights reserved.

#include <dispatch/dispatch.h>
#include <ableton/util/Injected.hpp>
#include "ABLLink.h"
#include "ABLLinkUtils.h"
#include "ABLLinkUtils.h"
#include "detail/ABLLinkAggregate.h"
#include "detail/ABLNotificationView.h"
#include "detail/ABLSettingsViewController.h"
#include "detail/BufferConversion.hpp"

// C API implementations for buffer conversion functions in ABLLinkUtils.h
extern "C"
{
  int16_t ABLConvertInt16(int16_t input) {
    return ableton::link_kit::ConvertInt16(input);
  }

  int16_t ABLConvertUInt16(uint16_t input) {
    return ableton::link_kit::ConvertUInt16(input);
  }

  int16_t ABLConvertInt32(int32_t input) {
    return ableton::link_kit::ConvertInt32(input);
  }

  int16_t ABLConvertUInt32(uint32_t input) {
    return ableton::link_kit::ConvertUInt32(input);
  }

  int16_t ABLConvertFloat(float input) {
    return ableton::link_kit::ConvertFloat(input);
  }
}

namespace {

// Wrappers that adapt AudioBufferList to the header-only buffer copy functions
template <typename T>
void SCopyBuffer(const uint32_t numFrames, AudioBufferList* input, int16_t* output) {
  T* src = (T*)input->mBuffers[0].mData;
  ableton::link_kit::CopyBufferMono(numFrames, src, output);
}

template <typename T>
void SCopyBufferStereo(const uint32_t numFrames, AudioBufferList* input, int16_t* output) {
  T* left = (T*)input->mBuffers[0].mData;
  T* right = (T*)input->mBuffers[1].mData;
  ableton::link_kit::CopyBufferStereoNonInterleaved(numFrames, left, right, output);
}

template <typename T>
void SCopyBufferStereoInterleaved(const uint32_t numFrames, AudioBufferList* input, int16_t* output) {
  T* src = (T*)input->mBuffers[0].mData;
  ableton::link_kit::CopyBufferStereoInterleaved(numFrames, src, output);
}

}

extern "C"
{
  ABLLink::ABLLink(const double initialBpm)
    : mpCallbacks(
        std::make_shared<ABLLinkCallbacks>(
          [](bool) { },
          [](bool) { },
          [](std::size_t) { },
          [](double) { },
          [](bool) { },
          [](bool) { },
          [](bool) { }
        )
      )
    , mActive(true)
    , mEnabled(false)
    , mImpl(initialBpm, "")
    , mAudioSessionState{mImpl.captureAudioSessionState(), mImpl.clock()}
    , mAppSessionState{mImpl.captureAppSessionState(), mImpl.clock()}
  {
    mpSettingsViewController = [[ABLSettingsViewController alloc] initWithLink:this];

    NSString* name = [[NSUserDefaults standardUserDefaults] objectForKey:ABLLinkPeerName];
    mImpl.setPeerName([name UTF8String]);

    mImpl.setNumPeersCallback(
      [this] (const std::size_t numPeers) {
        auto pCallbacks = mpCallbacks;
        dispatch_async(dispatch_get_main_queue(), ^{

          pCallbacks->mPeerCountCallback(numPeers);
        });
    });

    mImpl.setTempoCallback(
      [this] (const double tempo) {
        auto pCallbacks = mpCallbacks;
        dispatch_async(dispatch_get_main_queue(), ^{
          pCallbacks->mTempoCallback(tempo);
        });
    });

    mImpl.setStartStopCallback(
      [this] (const bool isStarted) {
        auto pCallbacks = mpCallbacks;
        dispatch_async(dispatch_get_main_queue(), ^{
         pCallbacks->mStartStopCallback(isStarted);
        });
    });

    const bool linkEnabled = [[NSUserDefaults standardUserDefaults] boolForKey:ABLLinkEnabledKey];
    mEnabled = linkEnabled;
    mpCallbacks->mIsEnabledCallback(linkEnabled);
    updateEnabled();

    const bool startStopSyncEnabled =
      [[NSUserDefaults standardUserDefaults] boolForKey:ABLLinkStartStopSyncEnabledKey];
    mImpl.enableStartStopSync(startStopSyncEnabled);
  }

  void ABLLink::updateEnabled()
  {
    mImpl.enable(mActive && mEnabled);
  }

  void ABLLink::enableStartStopSync(const bool enabled)
  {
    mImpl.enableStartStopSync(enabled);
  }

  bool ABLLink::isStartStopSyncEnabled()
  {
    return mImpl.isStartStopSyncEnabled();
  }

  void ABLLink::enableLinkAudio(const bool enabled)
  {
    mImpl.enableLinkAudio(enabled);
  }

  bool ABLLink::isLinkAudioEnabled()
  {
    return mImpl.isLinkAudioEnabled();
  }

  void ABLLink::setPeerName(const char* name)
  {
    mImpl.setPeerName(name);
  }

  ABLLinkAudioSink::ABLLinkAudioSink(ABLLink& link, const char* name, uint32_t maxNumSamples)
    : mImpl(link.mImpl, name, maxNumSamples)
  {
  }


  // ABLLink API

  ABLLinkRef ABLLinkNew(const double bpm)
  {
    ABLLink* ablLink = new ABLLink(bpm);
    // Install notification callback
    ablLink->mpCallbacks->mPeerCountCallback = [ablLink](const std::size_t peers) {
      if(ablLink->mImpl.isEnabled())
      {
        const size_t oldNumPeers = ablLink->mpSettingsViewController.numberOfPeers;
        if (oldNumPeers == 0 && peers > 0) {
          ablLink->mpCallbacks->mIsConnectedCallback(true);
        }
        else if (oldNumPeers > 0 && peers == 0) {
          ablLink->mpCallbacks->mIsConnectedCallback(false);
        }
        [ABLNotificationView showNotificationMessage:peers];
        [ablLink->mpSettingsViewController setNumberOfPeers:peers];
        
        [[NSNotificationCenter defaultCenter] postNotification:
            [NSNotification notificationWithName:@"ABLLink.NumberOfPeersChanged" object:[NSNumber numberWithUnsignedLongLong:peers]]];
      }
    };
    return ablLink;
  }

  void ABLLinkDelete(ABLLinkRef ablLink)
  {
    [ablLink->mpSettingsViewController deinit];

    // clear all callbacks before deletion so that they won't be
    // invoked during or after destruction of the library
    ablLink->mpCallbacks->mIsConnectedCallback = [](bool) { };
    ablLink->mpCallbacks->mIsEnabledCallback = [](bool) { };
    ablLink->mpCallbacks->mPeerCountCallback = [](std::size_t) { };
    ablLink->mpCallbacks->mTempoCallback = [](double) { };
    ablLink->mpCallbacks->mStartStopCallback = [](bool) { };
    ablLink->mpCallbacks->mIsStartStopSyncEnabledCallback = [](bool) { };
    ablLink->mpCallbacks->mIsAudioEnabledCallback = [](bool) { };

    delete ablLink;
  }

  void ABLLinkSetActive(ABLLinkRef ablLink, const bool active)
  {
    ablLink->mActive = active;
    ablLink->updateEnabled();
  }

  bool ABLLinkIsEnabled(ABLLinkRef ablLink)
  {
    return ablLink->mEnabled;
  }

  bool ABLLinkIsStartStopSyncEnabled(ABLLinkRef ablLink)
  {
    return ablLink->mImpl.isStartStopSyncEnabled();
  }

  bool ABLLinkIsConnected(ABLLinkRef ablLink)
  {
    return ablLink->mImpl.isEnabled() && ablLink->mImpl.numPeers() > 0;
  }

  void ABLLinkSetSessionTempoCallback(
    ABLLinkRef ablLink,
    ABLLinkSessionTempoCallback callback,
    void* context)
  {
    ablLink->mpCallbacks->mTempoCallback = [=](const double sessionTempo) {
      callback(sessionTempo, context);
    };
  }

  void ABLLinkSetStartStopCallback(
    ABLLinkRef ablLink,
    ABLLinkStartStopCallback callback,
    void* context)
  {
    ablLink->mpCallbacks->mStartStopCallback = [=](const bool isStarted) {
      callback(isStarted, context);
    };
  }

  void ABLLinkSetIsEnabledCallback(
    ABLLinkRef ablLink,
    ABLLinkIsEnabledCallback callback,
    void* context)
  {
    ablLink->mpCallbacks->mIsEnabledCallback = [=](const bool isEnabled) {
      callback(isEnabled, context);
    };
  }

  void ABLLinkSetIsStartStopSyncEnabledCallback(
    ABLLinkRef ablLink,
    ABLLinkIsStartStopSyncEnabledCallback callback,
    void* context)
  {
    ablLink->mpCallbacks->mIsStartStopSyncEnabledCallback = [=](const bool isEnabled) {
      callback(isEnabled, context);
    };
  }

    void ABLLinkSetIsAudioEnabledCallback(
    ABLLinkRef ablLink,
    ABLLinkIsAudioEnabledCallback callback,
    void* context)
  {
    ablLink->mpCallbacks->mIsAudioEnabledCallback = [=](const bool isEnabled) {
      callback(isEnabled, context);
    };
  }

  void ABLLinkSetIsConnectedCallback(
    ABLLinkRef ablLink,
    ABLLinkIsConnectedCallback callback,
    void* context)
  {
    ablLink->mpCallbacks->mIsConnectedCallback = [=](const bool isConnected) {
      callback(isConnected, context);
    };
  }

  ABLLinkSessionStateRef ABLLinkCaptureAudioSessionState(ABLLinkRef ablLink)
  {
    ablLink->mAudioSessionState.mImpl = ablLink->mImpl.captureAudioSessionState();
    ablLink->mAudioSessionState.mClock = ablLink->mImpl.clock();
    return &ablLink->mAudioSessionState;
  }

  void ABLLinkCommitAudioSessionState(ABLLinkRef ablLink, ABLLinkSessionStateRef sessionState)
  {
    ablLink->mImpl.commitAudioSessionState(sessionState->mImpl);
  }

  ABLLinkSessionStateRef ABLLinkCaptureAppSessionState(ABLLinkRef ablLink)
  {
    ablLink->mAppSessionState.mImpl = ablLink->mImpl.captureAppSessionState();
    ablLink->mAppSessionState.mClock = ablLink->mImpl.clock();
    return &ablLink->mAppSessionState;
  }

  void ABLLinkCommitAppSessionState(ABLLinkRef ablLink, ABLLinkSessionStateRef sessionState)
  {
    ablLink->mImpl.commitAppSessionState(sessionState->mImpl);
  }

  double ABLLinkGetTempo(ABLLinkSessionStateRef sessionState)
  {
    return sessionState->mImpl.tempo();
  }

  void ABLLinkSetTempo(
    ABLLinkSessionStateRef sessionState,
    const double bpm,
    const uint64_t hostTimeAtOutput)
  {
    const auto micros = sessionState->mClock.ticksToMicros(hostTimeAtOutput);
    sessionState->mImpl.setTempo(bpm, micros);
  }

  double ABLLinkBeatAtTime(
    ABLLinkSessionStateRef sessionState,
    const uint64_t hostTime,
    const double quantum)
  {
    const auto micros = sessionState->mClock.ticksToMicros(hostTime);
    return sessionState->mImpl.beatAtTime(micros, quantum);
  }

  double ABLLinkPhaseAtTime(
    ABLLinkSessionStateRef sessionState,
    const uint64_t hostTime,
    const double quantum)
  {
    const auto micros = sessionState->mClock.ticksToMicros(hostTime);
    return sessionState->mImpl.phaseAtTime(micros, quantum);
  }

  uint64_t ABLLinkTimeAtBeat(
    ABLLinkSessionStateRef sessionState,
    const double beatTime,
    const double quantum)
  {
    const auto micros = sessionState->mImpl.timeAtBeat(beatTime, quantum);
    return sessionState->mClock.microsToTicks(micros);
  }

  void ABLLinkRequestBeatAtTime(
    ABLLinkSessionStateRef sessionState,
    const double beatTime,
    const uint64_t hostTime,
    const double quantum)
  {
    auto micros = sessionState->mClock.ticksToMicros(hostTime);
    sessionState->mImpl.requestBeatAtTime(beatTime, micros, quantum);
  }

  void ABLLinkForceBeatAtTime(
    ABLLinkSessionStateRef sessionState,
    const double beatTime,
    const std::uint64_t hostTime,
    const double quantum)
  {
    auto micros = sessionState->mClock.ticksToMicros(hostTime);
    sessionState->mImpl.forceBeatAtTime(beatTime, micros, quantum);
  }

  void ABLLinkSetIsPlaying(
    ABLLinkSessionStateRef sessionState,
    const bool isPlaying,
    const uint64_t hostTime)
  {
    const auto micros = sessionState->mClock.ticksToMicros(hostTime);
    sessionState->mImpl.setIsPlaying(isPlaying, micros);
  }

  bool ABLLinkIsPlaying(ABLLinkSessionStateRef sessionState)
  {
    return sessionState->mImpl.isPlaying();
  }

  uint64_t ABLLinkTimeForIsPlaying(ABLLinkSessionStateRef sessionState)
  {
    return sessionState->mClock.microsToTicks(sessionState->mImpl.timeForIsPlaying());
  }

  void ABLLinkRequestBeatAtStartPlayingTime(
    ABLLinkSessionStateRef sessionState,
    const double beatTime,
    const double quantum)
  {
    sessionState->mImpl.requestBeatAtStartPlayingTime(beatTime, quantum);
  }

  void ABLLinkSetIsPlayingAndRequestBeatAtTime(
    ABLLinkSessionStateRef sessionState,
    bool isPlaying,
    uint64_t hostTime,
    double beatTime,
    double quantum)
  {
    const auto micros = sessionState->mClock.ticksToMicros(hostTime);
    sessionState->mImpl.setIsPlayingAndRequestBeatAtTime(isPlaying, micros, beatTime, quantum);
  }

  bool ABLLinkIsAudioEnabled(ABLLinkRef ablLink)
  {
    return ablLink->mImpl.isLinkAudioEnabled();
  }

  void ABLLinkSetPeerName(ABLLinkRef ablLink, const char* name)
  {
    ablLink->mImpl.setPeerName(name);
  }

  ABLLinkAudioSinkRef ABLLinkAudioSinkNew(ABLLinkRef ablLink, const char* name, const uint32_t maxNumSamples)
  {
    return new ABLLinkAudioSink(*ablLink, name, maxNumSamples);
  }

  void ABLLinkAudioSinkDelete(ABLLinkAudioSinkRef sink)
  {
    delete sink;
  }

  uint32_t ABLLinkAudioSinkMaxNumSamples(ABLLinkAudioSinkRef sink) {
    return static_cast<uint32_t>(sink->mImpl.maxNumSamples());
  }

  void ABLLinkAudioSinkRequestMaxNumSamples(ABLLinkAudioSinkRef sink, const uint32_t maxNumSamples)
  {
    sink->mImpl.requestMaxNumSamples(maxNumSamples);
  }

  ABLLinkAudioSinkBufferHandleRef ABLLinkAudioRetainBuffer(ABLLinkAudioSinkRef sink)
  {
    sink->mBufferHandle.moImpl.emplace(sink->mImpl);
    return &sink->mBufferHandle;
  }

  bool ABLLinkAudioSinkBufferHandleIsValid(ABLLinkAudioSinkBufferHandleRef bufferHandle)
  {
    return bufferHandle->moImpl.has_value() && *bufferHandle->moImpl;
  }

  int16_t* ABLLinkAudioSinkBufferSamples(ABLLinkAudioSinkBufferHandleRef bufferHandle)
  {
    return bufferHandle->moImpl->samples;
  }

  bool ABLLinkAudioReleaseAndCommitBuffer(
    ABLLinkAudioSinkRef sink,
    ABLLinkAudioSinkBufferHandleRef bufferHandle,
    ABLLinkSessionStateRef sessionState,
    const double beatsAtBufferBegin,
    const double quantum,
    const uint32_t numFrames,
    const uint32_t numChannels,
    const uint32_t sampleRate)
  {
    const auto result =sink->mBufferHandle.moImpl->commit(sessionState->mImpl, beatsAtBufferBegin, quantum, numFrames, numChannels, sampleRate);
    bufferHandle->moImpl.reset();
    return result;
  }

  void ABLLinkAudioReleaseBuffer(ABLLinkAudioSinkBufferHandleRef bufferHandle)
  {
    bufferHandle->moImpl.reset();
  }

  void ABLLinkSetPropertiesFromASBD(ABLLinkAudioSinkRef sink, const AudioStreamBasicDescription *asbd)
  {
    sink->mASBD = *asbd;
    sink->mImpl.requestMaxNumSamples(asbd->mChannelsPerFrame * asbd->mFramesPerPacket);

    sink->mBufferCopyFn = nullptr;

    if (sink->mASBD.mFormatID == kAudioFormatLinearPCM) {
      switch (sink->mASBD.mBitsPerChannel) {
        case 16: {
          if (asbd->mFormatFlags & kAudioFormatFlagIsSignedInteger) {
            if (asbd->mChannelsPerFrame == 1) {
              sink->mBufferCopyFn = &SCopyBuffer<int16_t>;
            } else {
              if (asbd->mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
                sink->mBufferCopyFn = &SCopyBufferStereo<int16_t>;
              } else {
                sink->mBufferCopyFn = &SCopyBufferStereoInterleaved<int16_t>;
              }
            }
          } else {
            if (asbd->mChannelsPerFrame == 1) {
                sink->mBufferCopyFn = &SCopyBuffer<uint16_t>;
            } else {
              if (asbd->mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
                sink->mBufferCopyFn = &SCopyBufferStereo<uint16_t>;
              } else {
                sink->mBufferCopyFn = &SCopyBufferStereoInterleaved<uint16_t>;
              }
            }
          }
          break;
        }
       case 32: {
         if (asbd->mFormatFlags & kAudioFormatFlagIsFloat) {
           if (asbd->mChannelsPerFrame == 1) {
             sink->mBufferCopyFn = &SCopyBuffer<float>;
           } else {
             if (asbd->mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
               sink->mBufferCopyFn = &SCopyBufferStereo<float>;
             } else {
               sink->mBufferCopyFn = &SCopyBufferStereoInterleaved<float>;
             }
           }
         } else if (asbd->mFormatFlags & kAudioFormatFlagIsSignedInteger) {
            if (asbd->mChannelsPerFrame == 1) {
              sink->mBufferCopyFn = &SCopyBuffer<int32_t>;
            } else {
              if (asbd->mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
                sink->mBufferCopyFn = &SCopyBufferStereo<int32_t>;
              } else {
                sink->mBufferCopyFn = &SCopyBufferStereoInterleaved<int32_t>;
              }
            }
          } else {
            if (asbd->mChannelsPerFrame == 1) {
              sink->mBufferCopyFn = &SCopyBuffer<uint32_t>;
            } else {
              if (asbd->mFormatFlags & kAudioFormatFlagIsNonInterleaved) {
                sink->mBufferCopyFn = &SCopyBufferStereo<uint32_t>;
              } else {
                sink->mBufferCopyFn = &SCopyBufferStereoInterleaved<uint32_t>;
              }
            }
          }
          break;
        }
        break;
        default:
          break;
      }
    }
  }

  bool ABLLinkCommitCoreAudioBufferWithBeats(
    ABLLinkAudioSinkRef sink,
    ABLLinkSessionStateRef sessionState,
    const double beatsAtBufferBegin,
    const double quantum,
    const uint32_t numFrames,
    AudioBufferList *ioData)
  {
    if (sink->mBufferCopyFn == nullptr || (sink->mImpl.maxNumSamples() >= sink->mASBD.mChannelsPerFrame * numFrames))
    {
      return false;
    }

    ABLLinkAudioSinkBufferHandleRef bufferHandle = ABLLinkAudioRetainBuffer(sink);
    if (ABLLinkAudioSinkBufferHandleIsValid(bufferHandle))
    {
      auto* output = ABLLinkAudioSinkBufferSamples(bufferHandle);
      sink->mBufferCopyFn(numFrames, ioData, output);
      return ABLLinkAudioReleaseAndCommitBuffer(sink, bufferHandle, sessionState, beatsAtBufferBegin, quantum, numFrames, sink->mASBD.mChannelsPerFrame, sink->mASBD.mSampleRate);
    }
    return false;
  }

  bool ABLLinkCommitCoreAudioBufferWithHostTime(
    ABLLinkAudioSinkRef sink,
    ABLLinkSessionStateRef sessionState,
    const uint64_t hostTimeAtBufferBegin,
    const double quantum,
    const uint32_t numFrames,
    AudioBufferList *ioData)
  {
    const double beatsAtBufferBegin = ABLLinkBeatAtTime(sessionState, hostTimeAtBufferBegin, quantum);
    return ABLLinkCommitCoreAudioBufferWithBeats(sink, sessionState, beatsAtBufferBegin, quantum, numFrames, ioData);
  }

} // extern "C"
