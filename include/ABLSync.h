// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

/**
    @file ABLSync.h
    @brief Cross-device shared tempo and quantized beat grid API for iOS

    Provides zero configuration peer discovery on a local wired or
    wifi network between multiple instances running on multiple
    devices. When peers are connected in a sync session, they
    share a common tempo and quantized beat grid.

    Each instance of the library has its own continuous, monotonic
    beat timeline that starts when the library is initialized and runs
    until the library instance is destroyed. The absolute values on
    this timeline are not meaningful (integral values are not
    special), but the rate at which this timeline increases over time
    reveals the shared tempo of the sync session. It is the client
    app's responsibility to relate its app-specific notion of song
    position to this beat timeline.
*/

#pragma once

#include <CoreAudio/CoreAudioTypes.h>

#ifdef __cplusplus
extern "C"
{
#endif

  /** Reference to an instance of the library. */
  typedef struct ABLSync* ABLSyncRef;

  /** Initialize the library, providing an initial tempo. */
  ABLSyncRef ABLSyncNew(Float64 initialBpm);

  /** Destroy the library instance and cleanup its associated resources. */
  void ABLSyncDelete(ABLSyncRef);


  /** Enable/disable syncing. When syncing is enabled, the library
      will browse for peers and establish a new sync session when
      any are found. If shouldEnable matches the current enabled
      state, the call is a noop.
  */
  void ABLSyncEnable(ABLSyncRef, bool shouldEnable);

  /** Is syncing currently enabled? **/
  bool ABLSyncIsEnabled(ABLSyncRef);


  /** Propose a new tempo to the sync session, specifying the beat
      time at which the change occurs. The new tempo will be
      used immediately by this instance, but it may be later
      overridden by other changes occuring in the session.
  */
  void ABLSyncProposeTempo(ABLSyncRef, Float64 bpm, Float64 beatTime);


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
  Float64 ABLSyncBeatTimeAtHostTime(ABLSyncRef, UInt64 hostTimeAtOutput);


  /** Conversion function to determine which host time at the device's output
      represents the given beat time value. This function does not guarantee
      a backwards conversion of the value returned by ABLSyncBeatTimeAtHostTime().
  */
  UInt64 ABLSyncHostTimeAtBeatTime(ABLSyncRef, Float64 beatTime);

  /** Quantize the given beat time according to the given quantum and
      the shared grid of the sync session. The returned quantized
      value will be the closest quantized beat time to the given beat
      time. This means the returned value will be in the range
      beatTime +/- (quantum/2).

      If there is no active sync session, the beatTime argument will
      be returned unmodified.
  */
  Float64 ABLSyncQuantizeBeatTime(ABLSyncRef, Float64 quantum, Float64 beatTime);

#ifdef __cplusplus
}
#endif
