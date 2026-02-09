// Copyright: 2018, Ableton AG, Berlin. All rights reserved.

#pragma once

#include <memory>
#include <ableton/Link.hpp>
#include "detail/ABLSettingsViewController.h"

extern "C"
{
  using IsConnectedCallback = std::function<void (bool)>;
  using IsEnabledCallback = std::function<void (bool)>;
  using PeerCountCallback = std::function<void (std::size_t)>;
  using TempoCallback = std::function<void (double)>;
  using StartStopCallback = std::function<void (bool)>;
  using IsStartStopSyncEnabledCallback = std::function<void (bool)>;

  struct ABLLinkCallbacks
  {
    ABLLinkCallbacks(
      IsConnectedCallback connected,
      IsEnabledCallback enabled,
      PeerCountCallback peerCount,
      TempoCallback tempo,
      StartStopCallback startStop,
      IsStartStopSyncEnabledCallback startStopSyncEnabled)
      : mIsConnectedCallback(std::move(connected))
      , mIsEnabledCallback(std::move(enabled))
      , mPeerCountCallback(std::move(peerCount))
      , mTempoCallback(std::move(tempo))
      , mStartStopCallback(std::move(startStop))
      , mIsStartStopSyncEnabledCallback(std::move(startStopSyncEnabled))
    {
    }

    IsConnectedCallback mIsConnectedCallback;
    IsEnabledCallback mIsEnabledCallback;
    PeerCountCallback mPeerCountCallback;
    TempoCallback mTempoCallback;
    StartStopCallback mStartStopCallback;
    IsStartStopSyncEnabledCallback mIsStartStopSyncEnabledCallback;
  };

  struct ABLLinkSessionState
  {
    ableton::Link::SessionState impl;
    ableton::Link::Clock clock;
  };

  struct ABLLink
  {
    ABLLink(double initialBpm);

    void updateEnabled();
    void enableStartStopSync(bool);
    bool isStartStopSyncEnabled();

    std::shared_ptr<ABLLinkCallbacks> mpCallbacks;
    bool mActive;
    std::atomic<bool> mEnabled;
    ableton::Link mImpl;
    ABLSettingsViewController *mpSettingsViewController;
    ABLLinkSessionState mAudioSessionState;
    ABLLinkSessionState mAppSessionState;
  };
}
