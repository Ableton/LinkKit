// Copyright: 2018, Ableton AG, Berlin. All rights reserved.

#include <dispatch/dispatch.h>
#include <ableton/util/Injected.hpp>
#include "ABLLink.h"
#include "ABLLinkUtils.h"
#include "detail/ABLLinkAggregate.h"
#include "detail/ABLNotificationView.h"
#include "detail/ABLSettingsViewController.h"


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
          [](bool) { }
        )
      )
    , mActive(true)
    , mEnabled(false)
    , mImpl(initialBpm)
    , mAudioSessionState{mImpl.captureAudioSessionState(), mImpl.clock()}
    , mAppSessionState{mImpl.captureAppSessionState(), mImpl.clock()}
  {
    mpSettingsViewController = [[ABLSettingsViewController alloc] initWithLink:this];

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

} // extern "C"
