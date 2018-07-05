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
    , mLink(initialBpm)
    , mAudioSessionState{mLink.captureAudioSessionState(), mLink.clock()}
    , mAppSessionState{mLink.captureAppSessionState(), mLink.clock()}
  {
    mpSettingsViewController = [[ABLSettingsViewController alloc] initWithLink:this];

    mLink.setNumPeersCallback(
      [this] (const std::size_t numPeers) {
        auto pCallbacks = mpCallbacks;
        dispatch_async(dispatch_get_main_queue(), ^{

          pCallbacks->mPeerCountCallback(numPeers);
        });
    });

    mLink.setTempoCallback(
      [this] (const double tempo) {
        auto pCallbacks = mpCallbacks;
        dispatch_async(dispatch_get_main_queue(), ^{
          pCallbacks->mTempoCallback(tempo);
        });
    });

    mLink.setStartStopCallback(
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
    mLink.enableStartStopSync(startStopSyncEnabled);
  }

  void ABLLink::updateEnabled()
  {
    mLink.enable(mActive && mEnabled);
  }

  void ABLLink::enableStartStopSync(const bool enabled)
  {
    mLink.enableStartStopSync(enabled);
  }

  bool ABLLink::isStartStopSyncEnabled()
  {
    return mLink.isStartStopSyncEnabled();
  }

  // ABLLink API

  ABLLinkRef ABLLinkNew(const double bpm)
  {
    ABLLink* ablLink = new ABLLink(bpm);
    // Install notification callback
    ablLink->mpCallbacks->mPeerCountCallback = [ablLink](const std::size_t peers) {
      if(ablLink->mLink.isEnabled())
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
    return ablLink->mLink.isStartStopSyncEnabled();
  }

  bool ABLLinkIsConnected(ABLLinkRef ablLink)
  {
    return ablLink->mLink.isEnabled() && ablLink->mLink.numPeers() > 0;
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
    ablLink->mAudioSessionState.impl = ablLink->mLink.captureAudioSessionState();
    ablLink->mAudioSessionState.clock = ablLink->mLink.clock();
    return &ablLink->mAudioSessionState;
  }

  void ABLLinkCommitAudioSessionState(ABLLinkRef ablLink, ABLLinkSessionStateRef sessionState)
  {
    ablLink->mLink.commitAudioSessionState(sessionState->impl);
  }

  ABLLinkSessionStateRef ABLLinkCaptureAppSessionState(ABLLinkRef ablLink)
  {
    ablLink->mAppSessionState.impl = ablLink->mLink.captureAppSessionState();
    ablLink->mAppSessionState.clock = ablLink->mLink.clock();
    return &ablLink->mAppSessionState;
  }

  void ABLLinkCommitAppSessionState(ABLLinkRef ablLink, ABLLinkSessionStateRef sessionState)
  {
    ablLink->mLink.commitAppSessionState(sessionState->impl);
  }

  double ABLLinkGetTempo(ABLLinkSessionStateRef sessionState)
  {
    return sessionState->impl.tempo();
  }

  void ABLLinkSetTempo(
    ABLLinkSessionStateRef sessionState,
    const double bpm,
    const uint64_t hostTimeAtOutput)
  {
    const auto micros = sessionState->clock.ticksToMicros(hostTimeAtOutput);
    sessionState->impl.setTempo(bpm, micros);
  }

  double ABLLinkBeatAtTime(
    ABLLinkSessionStateRef sessionState,
    const uint64_t hostTime,
    const double quantum)
  {
    const auto micros = sessionState->clock.ticksToMicros(hostTime);
    return sessionState->impl.beatAtTime(micros, quantum);
  }

  double ABLLinkPhaseAtTime(
    ABLLinkSessionStateRef sessionState,
    const uint64_t hostTime,
    const double quantum)
  {
    const auto micros = sessionState->clock.ticksToMicros(hostTime);
    return sessionState->impl.phaseAtTime(micros, quantum);
  }

  uint64_t ABLLinkTimeAtBeat(
    ABLLinkSessionStateRef sessionState,
    const double beatTime,
    const double quantum)
  {
    const auto micros = sessionState->impl.timeAtBeat(beatTime, quantum);
    return sessionState->clock.microsToTicks(micros);
  }

  void ABLLinkRequestBeatAtTime(
    ABLLinkSessionStateRef sessionState,
    const double beatTime,
    const uint64_t hostTime,
    const double quantum)
  {
    auto micros = sessionState->clock.ticksToMicros(hostTime);
    sessionState->impl.requestBeatAtTime(beatTime, micros, quantum);
  }

  void ABLLinkForceBeatAtTime(
    ABLLinkSessionStateRef sessionState,
    const double beatTime,
    const std::uint64_t hostTime,
    const double quantum)
  {
    auto micros = sessionState->clock.ticksToMicros(hostTime);
    sessionState->impl.forceBeatAtTime(beatTime, micros, quantum);
  }

  void ABLLinkSetIsPlaying(
    ABLLinkSessionStateRef sessionState,
    const bool isPlaying,
    const uint64_t hostTime)
  {
    const auto micros = sessionState->clock.ticksToMicros(hostTime);
    sessionState->impl.setIsPlaying(isPlaying, micros);
  }

  bool ABLLinkIsPlaying(ABLLinkSessionStateRef sessionState)
  {
    return sessionState->impl.isPlaying();
  }

  uint64_t ABLLinkTimeForIsPlaying(ABLLinkSessionStateRef sessionState)
  {
    return sessionState->clock.microsToTicks(sessionState->impl.timeForIsPlaying());
  }

  void ABLLinkRequestBeatAtStartPlayingTime(
    ABLLinkSessionStateRef sessionState,
    const double beatTime,
    const double quantum)
  {
    sessionState->impl.requestBeatAtStartPlayingTime(beatTime, quantum);
  }

  void ABLLinkSetIsPlayingAndRequestBeatAtTime(
    ABLLinkSessionStateRef sessionState,
    bool isPlaying,
    uint64_t hostTime,
    double beatTime,
    double quantum)
  {
    const auto micros = sessionState->clock.ticksToMicros(hostTime);
    sessionState->impl.setIsPlayingAndRequestBeatAtTime(isPlaying, micros, beatTime, quantum);
  }

} // extern "C"
