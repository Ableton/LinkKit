/*! @file ABLLink.h
    @copyright 2016, Ableton AG, Berlin. All rights reserved.
    @brief Cross-device shared tempo and quantized beat grid API for iOS

    @discussion Provides zero configuration peer discovery on a local
    wired or wifi network between multiple instances running on multiple
    devices. When peers are connected in a link session, they
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
  /*! @brief Reference to an instance of the library. */
  typedef struct ABLLink* ABLLinkRef;

  /*! @brief Initialize the library, providing an initial tempo and
      sync quantum.

      @discussion
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
  ABLLinkRef ABLLinkNew(double initialBpm, double syncQuantum);

  /*! @brief Destroy the library instance and cleanup its associated
      resources.
  */
  void ABLLinkDelete(ABLLinkRef);

  /*! @brief Set whether Link should be active or not.
      @discussion When Link is active, it advertises itself on the
      local network and initiates connections with other peers. It
      is active by default after init.
  */
  void ABLLinkSetActive(ABLLinkRef, bool active);

  /*! @brief Is Link currently enabled by the user?
      @discussion The enabled status is only controllable by the user
      via the Link settings dialog and is not controllable
      programmatically.
  */
  bool ABLLinkIsEnabled(ABLLinkRef);

  /*! @brief Is Link currently connected to other peers? */
  bool ABLLinkIsConnected(ABLLinkRef);

  /*! @brief Called if Session Tempo changes.
      @param sessionTempo User-visible representation of the session tempo as
      described in @link ABLLinkGetSessionTempo @/link
  */
  typedef void (*ABLLinkSessionTempoCallback)(
    double sessionTempo,
    void *context);

  /*! @brief Called if isEnabled state changes.
      @param isEnabled Whether Link is currently enabled
  */
  typedef void (*ABLLinkIsEnabledCallback)(
    bool isEnabled,
    void *context);


  /*! @brief Invoked on the main thread when the tempo of the Link
      session changes.
  */
  void ABLLinkSetSessionTempoCallback(
    ABLLinkRef,
    ABLLinkSessionTempoCallback callback,
    void* context);

  /*! @brief Invoked on the main thread when the user changes the
      enabled state of the library via the Link settings view.
  */
  void ABLLinkSetIsEnabledCallback(
    ABLLinkRef,
    ABLLinkIsEnabledCallback callback,
    void* context);

  /*! @brief Propose a new tempo to the link session.
      @param bpm The new tempo to be used by the session.
      @param hostTimeAtOutput The host time at which the change should
      occur. If the host time is too far in the past or future, the
      proposal may be rejected.
  */
  void ABLLinkProposeTempo(
    ABLLinkRef,
    double bpm,
    uint64_t hostTimeAtOutput);

  /*! @brief Get the current tempo for the link session in Beats Per
      Minute.
      @discussion This is a stable value that is appropriate for display
      to the user (unlike the value derived for a given audio buffer,
      which will vary due to clock drift, latency compensation, etc.)
  */
  double ABLLinkGetSessionTempo(ABLLinkRef);

  /*! @brief Conversion function to determine which value on the beat
      timeline should be hitting the device's output at the given host
      time.
      @discussion In order to determine the host time at the device
      output, the AVAudioSession outputLatency property must be taken
      into consideration along with any additional buffering latency
      introduced by the software. This function guarantees a
      proportional relationship between hostTimeAtOutput and the
      resulting beat time: hostTime_2 > hostTime_1 => beatTime_2 >
      beatTime_1 when called twice from the same thread.
  */
  double ABLLinkBeatTimeAtHostTime(ABLLinkRef, uint64_t hostTimeAtOutput);

  /*! @brief Conversion function to determine which host time at the
      device's output represents the given beat time value.
      @discussion This function does not guarantee a backwards
      conversion of the value returned by ABLLinkBeatTimeAtHostTime.
  */
  uint64_t ABLLinkHostTimeAtBeatTime(ABLLinkRef, double beatTime);


  /*! @brief Reset the beat timeline with a desire to map the given
      beat time to the given host time, returning the actual beat time
      value that maps to the given host time.
      @discussion The returned value will differ from the requested
      beat time by up to a quantum due to quantization, but will
      always be less than or equal to the given beat time.
  */
  double ABLLinkResetBeatTime(
    ABLLinkRef,
    double beatTime,
    uint64_t hostTimeAtOutput);


  /*! @brief Set the value used for quantization to the shared beat
      grid.
      @param quantum in beats.
      @discussion The quantum value set here will be used when joining
      a session and whenresetting the beat timeline with
      @link ABLLinkResetBeatTime @/link. It doesn't affect the
      results of the beat time / host time conversion functions and
      therefore will not cause a beat time jump if invoked while playing.
  */
  void ABLLinkSetQuantum(ABLLinkRef, double quantum);

  /*! @brief Get the value currently being used by the system for
      quantization to the shared beat grid.
  */
  double ABLLinkGetQuantum(ABLLinkRef);

  /*! @brief Get the phase for a given beat time value on the shared
      beat grid with respect to the given quantum.

      @discussion The beat timeline exposed by the ABLLink functions
      are aligned to the shared beat grid according to the quantum
      value that was set at initialization or at the last call to
      ABLLinkResetBeatTime. This function allows access to the phase
      of beat time values with respect to other quanta. The returned
      value will be in the range [0, quantum).
  */
  double ABLLinkPhase(ABLLinkRef, double beatTime, double quantum);

#ifdef __cplusplus
}
#endif
