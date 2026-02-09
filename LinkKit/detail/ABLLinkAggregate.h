// Copyright: 2018, Ableton AG, Berlin. All rights reserved.

#pragma once

#include <optional>
#include <memory>
#include <ableton/LinkAudio.hpp>
#include <AudioToolbox/AudioToolbox.h>
#include "detail/ABLSettingsViewController.h"

extern "C"
{
  using IsConnectedCallback = std::function<void (bool)>;
  using IsEnabledCallback = std::function<void (bool)>;
  using PeerCountCallback = std::function<void (std::size_t)>;
  using TempoCallback = std::function<void (double)>;
  using StartStopCallback = std::function<void (bool)>;
  using IsStartStopSyncEnabledCallback = std::function<void (bool)>;
  using IsAudioEnabledCallback = std::function<void (bool)>;

  struct ABLLinkCallbacks
  {
    ABLLinkCallbacks(
      IsConnectedCallback connected,
      IsEnabledCallback enabled,
      PeerCountCallback peerCount,
      TempoCallback tempo,
      StartStopCallback startStop,
      IsStartStopSyncEnabledCallback startStopSyncEnabled,
      IsAudioEnabledCallback audioEnabled)
      : mIsConnectedCallback(std::move(connected))
      , mIsEnabledCallback(std::move(enabled))
      , mPeerCountCallback(std::move(peerCount))
      , mTempoCallback(std::move(tempo))
      , mStartStopCallback(std::move(startStop))
      , mIsStartStopSyncEnabledCallback(std::move(startStopSyncEnabled))
      , mIsAudioEnabledCallback(std::move(audioEnabled))
    {
    }

    IsConnectedCallback mIsConnectedCallback;
    IsEnabledCallback mIsEnabledCallback;
    PeerCountCallback mPeerCountCallback;
    TempoCallback mTempoCallback;
    StartStopCallback mStartStopCallback;
    IsStartStopSyncEnabledCallback mIsStartStopSyncEnabledCallback;
    IsAudioEnabledCallback mIsAudioEnabledCallback;
  };

  struct ABLLinkSessionState
  {
    ableton::Link::SessionState mImpl;
    ableton::Link::Clock mClock;
  };

  struct ABLLink
  {
    ABLLink(double initialBpm);

    void updateEnabled();
    void enableStartStopSync(bool);
    bool isStartStopSyncEnabled();
    void enableLinkAudio(bool);
    bool isLinkAudioEnabled();

    std::shared_ptr<ABLLinkCallbacks> mpCallbacks;
    bool mActive;
    std::atomic<bool> mEnabled;
    ableton::LinkAudio mImpl;
    ABLSettingsViewController *mpSettingsViewController;
    ABLLinkSessionState mAudioSessionState;
    ABLLinkSessionState mAppSessionState;
  };

  struct ABLLinkAudioSinkBufferHandle {
    std::optional<ableton::LinkAudioSink::BufferHandle> moImpl;
  };

  typedef void (*BufferCopyFn)(const uint32_t numFrames, AudioBufferList* input, int16_t* output);

  struct ABLLinkAudioSink
  {
    ABLLinkAudioSink(ABLLink& link, const char* name, uint32_t maxNumSamples);

    ableton::LinkAudioSink mImpl;
    ABLLinkAudioSinkBufferHandle mBufferHandle;
    AudioStreamBasicDescription mASBD;
    BufferCopyFn mBufferCopyFn = nullptr;
  };
}
