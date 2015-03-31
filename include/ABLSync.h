// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

/**
    @file ABLSync.h
    @brief Clock, transport, and tempo syncing API

    It provides the capability to synchronize tempo and playback across multiple
    applications on multiple devices over a local wired or wifi network.
*/

#pragma once

#include <CoreAudio/CoreAudioTypes.h>

#ifdef __cplusplus
extern "C"
{
#endif

  /** Type that represents values on the shared timeline */
  typedef Float64 ABLSharedTime;

  /** @name Interface to ABLSync */
  /** Reference to sync session. */
  typedef struct ABLSync* ABLSyncRef;

  /** @name Initialization and configuration */
  /** Start a new sync session with the given output latency in seconds.

      @return Reference to sync session.
      @param outputLatency This is defined as the time between the audio
      timestamp given by the system's audio callback and the time of the
      soundcard's output of the corresponding audio. On iOS this corresponds to
      the outputLatency property of AVAudioSession.
  */
  ABLSyncRef ABLSyncNewSession(Float64 outputLatency);

  /** End the sync session and cleanup resources. */
  void ABLSyncDeleteSession(ABLSyncRef);

  /** This function must be called when the output latency of the audio system
      changes.
      @param latency See outputLatency description in ABLSyncNewSession().
  */
  void ABLSyncUpdateOutputLatency(ABLSyncRef, Float64 latency);


  /** @name Activate/Deactivate Connectivity */
  /** Activate Network communication. Browse for peers and connect
      automatically whenever any peers are found.
  */
  void ABLSyncActivateConnectivity(ABLSyncRef);

  /** Disconnect from all peers and deactivate network communication. */
  void ABLSyncDeactivateConnectivity(ABLSyncRef);


  /** @name Application-level API for observing the state of the system

      The query and callback registration functions are intended to be
      called from the main thread. Callbacks will be invoked on the
      main thread.
   */
  /** @return Whether the transport is currently playing. */
  bool ABLSyncGetIsTransportPlaying(ABLSyncRef);

  /** @return The current tempo in Bpm.

      The Bpm returned here is the shared tempo of the session. This
      is a value that is appropriate for display to the user but may
      not be exactly the tempo used to drive the audio engine. The
      tempo provided by the ABLSyncBpmAtSharedTime() function in the audio
      thread section may deviate slightly from the value reported
      here because it is adjusted for device clock drift.
   */
  Float32 ABLSyncGetSharedBpm(ABLSyncRef);

  /** @return Whether the client is connected to at least one other
      peer.
   */
  bool ABLSyncGetIsConnected(ABLSyncRef);

  /** @return The current SharedTime
   */
  ABLSharedTime ABLSyncGetSharedTime(ABLSyncRef);

  /** @name Callbacks for observing changes in the system state */
  /** Called if either transport state, Bpm, or both change.
      @param eventAt Shared time of given state changes
      @param isPlaying Whether the client is playing
      @param sharedBpm The Bpm value provided by this callback is the
      user-visible representation of the shared tempo as described in
      ABLSyncGetSharedBpm()
   */
  typedef void (*ABLSyncEventCallback)(
    ABLSharedTime eventAt,
    bool isPlaying,
    Float32 sharedBpm,
    void *context);

  /** Called if connection state changes.
      @param isConnected Whether the client is connected to at least one other
      peer
  */
  typedef void (*ABLSyncConnectionStateCallback)(
    bool isConnected,
    void *context);


  /** @name Callback Registration
   * Setters for delegate notifications. */
  void ABLSyncSetEventCallback(
    ABLSyncRef,
    ABLSyncEventCallback callback,
    void* context);

  void ABLSyncSetConnectionStateCallback(
    ABLSyncRef,
    ABLSyncConnectionStateCallback callback,
    void* context);


  /** @name Proposal functions
      Proposals are not satisfied immediately and can be rejected by
      the system. They are handled as soon as possible and are not
      guaranteed to happen at specific points in time. Proposals are
      non-blocking but should not be called from the audio thread. */

  /** Propose transport start at the given position on the shared
      timeline.
      @param startAtSharedTime This Value only specifies the position,
      the start action will happen as soon as possible. This start time
      will not be honored if the shared timeline is already running.
   */
  void ABLSyncProposeTransportStart(
    ABLSyncRef,
    ABLSharedTime startAtSharedTime);

  /** Propose transport stop. */
  void ABLSyncProposeTransportStop(ABLSyncRef);

  /** Propose a change of the session's shared tempo. Tempo change
      proposals can be rejected for two reasons:
      -# It is out of the accepted Bpm range of 20 - 999
      -# Another participant is currently changing the tempo
   */
  void ABLSyncProposeBpm(ABLSyncRef, Float32 bpm);


  /** @name Audio thread types */
  /** Reference to a data type that represents a contiguous range of time
      within a buffer in which the client should be playing audio. There may
      be multiple ranges within a buffer. Each range has a constant tempo and
      a start and end point within the buffer. It therefore defines a linear
      mapping between shared time and sample offsets into its associated buffer.
      See ABLSyncSharedTimeAtSampleOffset and ABLSyncSampleOffsetAtSharedTime
      functions to convert between these coordinate systems within a range.

      Tempo changes that occur within a buffer are modeled as multiple
      contiguous ranges, each with a different tempo. The ranges therefore
      represent a sampling of the tempo curve of the session.
  */
  typedef const struct ABLSyncPlayRange* ABLSyncPlayRangeRef;


  /** @name Audio thread functions */
  /** This function must be called for every buffer while the audio
      system is running.
      @return #ABLSyncPlayRangeRef The first play range in the buffer. This
      range may be invalid if the app should not be playing during this
      entire buffer. Clients must test for this case with
      ABLSyncIsValidPlayRange.
      @param inTimeStamp Buffer's CoreAudio timestamp
      @param inNumberFrames Buffer size as provided to the audio callback
      @param sampleRate Sample rate in Hertz
   */

  ABLSyncPlayRangeRef ABLSyncSynchronizeBuffer(
    ABLSyncRef,
    const AudioTimeStamp* inTimeStamp,
    UInt32 inNumberFrames,
    Float64 sampleRate);

  /** @return Whether the given play range is valid

      A play range is valid if it represents a non-empty subset of an
      audio buffer. The tempo and start/end time of an invalid range are
      undefined, so clients should not use an invalid range as an argument
      to any of the range query functions.
      An invalid range is used to mark the end of the sequence
      of ranges returned by ABLSyncSynchronizeBuffer, so this function
      should be used to test for the end of this sequence.
  */
  bool ABLSyncIsValidPlayRange(ABLSyncRef, ABLSyncPlayRangeRef);

  /** @return The iterator that represents the next event in the list.

      The resulting iterator should be tested with ABLSyncIsValidPlayRange().
  */
  ABLSyncPlayRangeRef ABLSyncNextPlayRange(ABLSyncPlayRangeRef);

  /** @return The tempo in beats per minute within the given play range.
      The result is undefined for an invalid play range.

      The bpm value provided by this function may differ slightly from
      the shared tempo because it is adjusted in order to compensate
      for clock drift. This value should be interepreted as the tempo
      at which to run the audio engine in order to stay in sync with
      the shared timeline. It should not be directly displayed to the
      user as it will be slightly different from the shared tempo.
  */
  Float32 ABLSyncBpmInPlayRange(ABLSyncPlayRangeRef);

  /** @return The shared time at the beginning of the given range. The
      result is undefined for an invalid play range.
   */
  ABLSharedTime ABLSyncSharedTimeAtPlayRangeStart(ABLSyncPlayRangeRef);

  /** @return The shared time at the end of the given range. The
      result is undefined for an invalid play range.
   */
  ABLSharedTime ABLSyncSharedTimeAtPlayRangeEnd(ABLSyncPlayRangeRef);

  /** @return The shared time value corresponding to the given sample
      offset as defined by the given play range. This is only really useful
      for sample offsets that occur within the given range, but this
      function will extrapolate for inputs outside of the range according
      to the tempo of the range.
  */
  ABLSharedTime ABLSyncSharedTimeAtSampleOffset(
    ABLSyncPlayRangeRef,
    Float64 sampleOffset);

  /** @return The sample offset corresponding to the given shared time as
      defined by the given play range. This is only really useful for shared
      time values that oocur within the given range, but function will
      extrapolate for inputs outside of the range according to the tempo of
      the range.
  */
  Float64 ABLSyncSampleOffsetAtSharedTime(
    ABLSyncPlayRangeRef,
    ABLSharedTime sharedTime);

#ifdef __cplusplus
}
#endif
