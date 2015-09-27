// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

/**
    @file ABLSync.h
    @brief Cross-device shared tempo and quantized beat grid API for iOS

    Provides zero configuration peer discovery on a local wired or
    wifi network between multiple instances running on multiple
    devices. When peers are connected in a sync session, they
    share a common tempo and quantized beat grid.

    Each instance of the library has its own  beat timeline that
    starts when the library is initialized and runs
    until the library instance is destroyed. Clients can reset the
    beat timeline in order to align it with an app's beat position
    when starting playback.
*/

#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

  /** Reference to an instance of the library. */
  typedef struct ABLSync* ABLSyncRef;

  /** Initialize the library, providing an initial tempo and
      sync quantum.

      The sync quantum is a value in beats that represents the
      granularity of synchronizaton with the shared
      quantization grid. A reasonable default value would be 1, which
      would guarantee that beat onsets would be synchronized with the
      session. Higher values would provide phase synchronization
      across multiple beats. For example, a value of 4 would cause
      this instance to be aligned to a 4/4 bar with any other
      instances in the session that have a quantum of 4 (or a multiple
      of 4).
  */
  ABLSyncRef ABLSyncNew(double initialBpm, double syncQuantum);

  /** Destroy the library instance and cleanup its associated resources. */
  void ABLSyncDelete(ABLSyncRef);


  /** Is syncing currently enabled? **/
  bool ABLSyncIsEnabled(ABLSyncRef);


  /** @name Callbacks for observing changes in the system state */
  /** Called if Session Tempo changes.
      @param sessionTempo User-visible representation of the session tempo as
      described in ABLSyncGetSessionTempo()
  */
  typedef void (*ABLSyncSessionTempoCallback)(
    double sessionTempo,
    void *context);

  /** Called if isEnabled state changes.
      @param isEnabled Whether syncing is currently enabled
  */
  typedef void (*ABLSyncIsEnabledCallback)(
    bool isEnabled,
    void *context);


  /** @name Callback Registration
   * Setters for delegate notifications. */
  void ABLSyncSetSessionTempoCallback(
    ABLSyncRef,
    ABLSyncSessionTempoCallback callback,
    void* context);

  void ABLSyncSetIsEnabledCallback(
    ABLSyncRef,
    ABLSyncIsEnabledCallback callback,
    void* context);


  /** Propose a new tempo to the sync session, specifying the host time
      at which the change should occur. If the host time is too far in
      the past or future it will be rejected.
  */
  void ABLSyncProposeTempo(
    ABLSyncRef,
    double bpm,
    uint64_t hostTimeAtOutput);

  /** Get the current tempo for the sync session in Beats Per
      Minute. This is a stable value that is appropriate for display
      to the user (unlike the value derived for a given audio buffer,
      which will vary due to clock drift, latency compensation, etc.)
  */
  double ABLSyncGetSessionTempo(ABLSyncRef);

  /** Conversion function to determine which value on the beat
      timeline should be hitting the device's output at the given host
      time. In order to determine the host time at the device output,
      the AVAudioSession outputLatency property must be taken into
      consideration along with any additional buffering latency
      introduced by the software. This function guarantees a
      proportional relationship between @hostTimeAtOutput and the
      resulting beat time: hostTime_2 > hostTime_1 => beatTime_2 >
      beatTime_1 when called twice from the same thread.
  */
  double ABLSyncBeatTimeAtHostTime(ABLSyncRef, uint64_t hostTimeAtOutput);

  /** Conversion function to determine which host time at the device's output
      represents the given beat time value. This function does not guarantee
      a backwards conversion of the value returned by ABLSyncBeatTimeAtHostTime.
  */
  uint64_t ABLSyncHostTimeAtBeatTime(ABLSyncRef, double beatTime);


  /** Reset the beat timeline with a desire to map the given beat time
      to the given host time, returning the actual beat time value
      that maps to the given host time. The returned value will differ
      from the requested beat time by up to a quantum due to
      quantization, but will always be <= the given beat time.
  */
  double ABLSyncResetBeatTime(
    ABLSyncRef,
    double beatTime,
    uint64_t hostTimeAtOutput);


  /** Set the value used for quantization to the shared beat grid.
      This value is specified in beats. Changing the quantum during
      playback may result in beat time jumps in order to align to the
      new value.
  */
  void ABLSyncSetQuantum(ABLSyncRef, double quantum);

  /** Get the value currently being used by the system for
      quantization to the shared beat grid.
  */
  double ABLSyncGetQuantum(ABLSyncRef);

#ifdef __cplusplus
}
#endif
