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
  /** The central concept of the ABLSync library is a timeline that is shared by
      all participants. This shared timeline corresponds to musical beats -
      units on the timeline represent 96th notes (as in MIDI clock sync).

      Since the timeline is distributed amongst all participants, it will
      continue as long as any participant is still playing. This means that
      there is no need to designate a participant as the Master and the session
      can continue even after the first participant has left.
  */
  typedef Float64 SharedTime;

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


  /** @name Callbacks for observing changes in the system state */
  /** Called if either transport state, Bpm, or both change.
      @param eventAt Shared time of given state changes
      @param isPlaying Whether the client is playing
      @param sharedBpm The Bpm value provided by this callback is the
      user-visible representation of the shared tempo as described in
      ABLSyncGetSharedBpm()
   */
  typedef void (*ABLSyncEventCallback)(
    SharedTime eventAt,
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
  void ABLSyncProposeTransportStart(ABLSyncRef, SharedTime startAtSharedTime);

  /** Propose transport stop. */
  void ABLSyncProposeTransportStop(ABLSyncRef);

  /** Propose a change of the session's shared tempo. Tempo change
      proposals can be rejected for two reasons:
      -# It is out of the accepted Bpm range of 20 - 999
      -# Another participant is currently changing the tempo
   */
  void ABLSyncProposeBpm(ABLSyncRef, Float32 bpm);


  /** @name Audio thread types */
  /** Data type representing sync information computed for a particular
      audio buffer.
  */
  typedef const struct ABLSyncBufferInfo* ABLSyncBufferInfoRef;

  /** Data type providing iteration over the sync events occuring in a
      particular audio buffer. Sync events represent either a change
      in transport state or a change in tempo.
  */
  typedef const struct ABLSyncEventIterator* ABLSyncEventIteratorRef;

  /** @name Audio thread functions */
  /** This function must be called for every buffer while the audio
      system is running.
      @return #ABLSyncBufferInfoRef This should be
      used to compute mappings between shared time and buffer sample
      offset. It also provides access to transport and tempo change
      events that occur within the buffer.
      @param inTimeStamp Buffer's CoreAudio timestamp
      @param inNumberFrames Buffer size as provided to the audio callback
      @param sampleRate Sample rate in Hertz
   */
  ABLSyncBufferInfoRef ABLSyncSynchronizeBuffer(
    ABLSyncRef,
    const AudioTimeStamp* inTimeStamp,
    UInt32 inNumberFrames,
    Float64 sampleRate);

  /** @return An iterator over the events in the buffer.
   
      If no events occurred in the buffer, the returned iterator ref will be
      at the end (meaning that ABLSyncEventIteratorAtEnd() will return @a true)
  */
  ABLSyncEventIteratorRef ABLSyncBufferEvents(ABLSyncBufferInfoRef);

  /** @return Whether the given iterator is at the end of the event list.

      Clients should not use an iterator that is at the end of the
      list, so this function should be used to test the iterator
      before passing it to other functions.
  */
  bool ABLSyncEventIteratorAtEnd(ABLSyncEventIteratorRef);

  /** @return The iterator that represents the next event in the list.
   
      The resulting iterator should be tested with ABLSyncEventIteratorAtEnd().
  */
  ABLSyncEventIteratorRef ABLSyncEventIteratorNext(ABLSyncEventIteratorRef);

  /** @return The shared time value for the event represented by the given
      iterator.
  */
  SharedTime ABLSyncEventTime(ABLSyncEventIteratorRef);

  /** @return The shared time value corresponding to the given sample
      offset into the associated buffer.
  */
  SharedTime ABLSyncSharedTimeAtSampleOffset(
    ABLSyncBufferInfoRef,
    Float32 sampleOffset);

  /** @return The sample offset into the associated buffer corresponding
      to the given shared time value.
  */
  Float32 ABLSyncSampleOffsetAtSharedTime(
    ABLSyncBufferInfoRef,
    SharedTime sharedTime);

  /** @return Whether the client should be playing at the given shared time.

      The result is only valid if the given shared time occurs within the
      associated buffer.
  */
  bool ABLSyncIsPlayingAtSharedTime(
    ABLSyncBufferInfoRef,
    SharedTime sharedTime);

  /** @return The tempo in Bpm at the given shared time value.
   
      The result is only valid if the given shared time occurs within the
      associated buffer.

      The Bpm value provided by this function may differ slightly from
      the shared tempo because it is adjusted in order to compensate
      for clock drift. This value should be interepreted as the tempo
      at which to run the audio engine in order to stay in sync with
      the shared timeline. It should not be directly displayed to the
      user as it will be slightly different from the shared tempo.
  */
  Float32 ABLSyncBpmAtSharedTime(ABLSyncBufferInfoRef, SharedTime sharedTime);

#ifdef __cplusplus
}
#endif
