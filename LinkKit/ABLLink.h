/*! @file ABLLink.h
 *  @copyright 2018, Ableton AG, Berlin. All rights reserved.
 *
 *  @brief Cross-device shared tempo, quantized beat grid and start/stop
 *  synchronization API for iOS
 *
 *  @discussion Provides zero configuration peer discovery on a local
 *  wired or wifi network between multiple instances running on
 *  multiple devices. When peers are connected in a link session, they
 *  share a common tempo and quantized beat grid.
 *
 *  Each instance of the library has its own session state which represents
 *  a beat timeline and a transport start/stop state. The timeline starts
 *  when the library is initialized and runs until the library
 *  instance is destroyed. Clients can reset the beat timeline in
 *  order to align it with an app's beat position when starting
 *  playback.
 *  Synchronizing to the transport start/stop state of Link is optional
 *  for every peer. The transport start/stop state is only shared with
 *  other peers when start/stop synchronization is enabled.
 *
 *  The library provides one session state capture/commit function pair for
 *  use in the audio thread and one for the main application
 *  thread. In general, modifying the Link session state should be done in
 *  the audio thread for the most accurate timing results. The ability
 *  to modify the Link session state from application threads should only
 *  be used in cases where an application's audio thread is not
 *  actively running or if it doesn't generate audio at all. Modifying
 *  the Link session state from both the audio thread and an application
 *  thread concurrently is not advised and will potentially lead to
 *  unexpected behavior.
 */

#pragma once

#include <stdbool.h>
#include <stdint.h>
#include <AudioToolbox/AudioToolbox.h>

#ifdef __cplusplus
extern "C"
{
#endif
  /*! @brief Reference to an instance of the library. */
  typedef struct ABLLink* ABLLinkRef;

  /*! @brief Initialize the library, providing an initial tempo.
   */
  ABLLinkRef ABLLinkNew(double initialBpm);

  /*! @brief Destroy the library instance and cleanup its associated
   *  resources.
   */
  void ABLLinkDelete(ABLLinkRef);

  /*! @brief Set whether Link should be active or not.
   *
   *  @discussion When Link is active, it advertises itself on the
   *  local network and initiates connections with other peers. It
   *  is active by default after init.
   */
  void ABLLinkSetActive(ABLLinkRef, bool active);

  /*! @brief Is Link currently enabled by the user?
   *
   *  @discussion The enabled status is only controllable by the user
   *  via the Link settings dialog and is not controllable
   *  programmatically.
   */
  bool ABLLinkIsEnabled(ABLLinkRef);

  /*! @brief Is Link currently connected to other peers? */
  bool ABLLinkIsConnected(ABLLinkRef);

  /*! @brief Is Start Stop Sync currently enabled by the user?
   *
   *  @discussion The Start Stop Sync Enabled status is only controllable
   *  by the user via the Link settings dialog and is not controllable
   *  programmatically.
   *  To allow the user to enable Start Stop Sync a Boolean entry YES under
   *  the key ABLLinkStartStopSyncSupported must be added to Info.plist.
   */
  bool ABLLinkIsStartStopSyncEnabled(ABLLinkRef);

  /*! @brief Called if Session Tempo changes.
   *
   *  @param sessionTempo New session tempo in bpm
   *
   *  @discussion This is a stable value that is appropriate for display
   *  to the user.
   */
  typedef void (*ABLLinkSessionTempoCallback)(
    double sessionTempo,
    void *context);

  /*! @brief Called if Session transport start/stop state changes.
   *
   *  @param isPlaying New start/stop state
   */
  typedef void (*ABLLinkStartStopCallback)(
    bool isPlaying,
    void *context);

  /*! @brief Called if isEnabled state changes.
   *
   *  @param isEnabled Whether Link is currently enabled
   */
  typedef void (*ABLLinkIsEnabledCallback)(
    bool isEnabled,
    void *context);

  /*! @brief Called if IsStartStopSyncEnabled state changes.
   *
   *  @param isEnabled Whether Start Stop Sync is currently enabled.
   */
  typedef void (*ABLLinkIsStartStopSyncEnabledCallback)(
    bool isEnabled,
    void *context);

  /*! @brief Called if IsAudioEnabled state changes.
   *
   *  @param isEnabled Whether audio sharing is currently enabled.
   */
  typedef void (*ABLLinkIsAudioEnabledCallback)(
    bool isEnabled,
    void *context);

  /*! @brief Called if isConnected state changes.
   *
   *  @param isConnected Whether Link is currently connected to other
   *  peers.
   */
  typedef void (*ABLLinkIsConnectedCallback)(
    bool isConnected,
    void *context);

  /*! @brief Invoked on the main thread when the tempo of the Link
   *  session changes.
   */
  void ABLLinkSetSessionTempoCallback(
    ABLLinkRef,
    ABLLinkSessionTempoCallback callback,
    void* context);

  /*! @brief Invoked on the main thread when the Start/stop state of
   *  the Link session changes.
   */
  void ABLLinkSetStartStopCallback(
    ABLLinkRef,
    ABLLinkStartStopCallback callback,
    void* context);

  /*! @brief Invoked on the main thread when the user changes the
   *  enabled state of the library via the Link settings view.
   */
  void ABLLinkSetIsEnabledCallback(
    ABLLinkRef,
    ABLLinkIsEnabledCallback callback,
    void* context);

  /*! @brief Invoked on the main thread when the user changes the
   *  start stop sync enabled state via the Link settings view.
   */
  void ABLLinkSetIsStartStopSyncEnabledCallback(
    ABLLinkRef,
    ABLLinkIsStartStopSyncEnabledCallback callback,
    void* context);

  /*! @brief Invoked on the main thread when the isConnected state
   *  of the library changes.
   */
  void ABLLinkSetIsConnectedCallback(
    ABLLinkRef,
    ABLLinkIsConnectedCallback callback,
    void* context);

  /*! @brief A reference to a representation of Link's session state.
   *
   *  @discussion A session state represents a timeline and the start/stop
   *  state. The timeline is a representation of a mapping between time and
   *  beats for varying quanta. The start/stop state represents the user
   *  intention to start or stop transport at a specific time. Start stop
   *  synchronization is an optional feature that allows to share the user
   *  request to start or stop transport between a subgroup of peers in a
   *  Link session. When observing a change of start/stop state, audio
   *  playback of a peer should be started or stopped the same way it would
   *  have happened if the user had requested that change at the according
   *  time locally. The start/stop state can only be changed by the user.
   *  This means that the current local start/stop state persists when
   *  joining or leaving a Link session. After joining a Link session
   *  start/stop change requests will be communicated to all connected peers.
   */
  typedef struct ABLLinkSessionState* ABLLinkSessionStateRef;

  /*! @brief Capture the current Link session state from the audio thread.
   *
   *  @discussion This function is lockfree and should ONLY be called
   *  in the audio thread. It must not be accessed from any other
   *  threads. The returned reference refers to a snapshot of the
   *  current session state, so it should be captured and used in a local
   *  scope. Storing the session state for later use in a different context
   *  is not advised because it will provide an outdated view on the
   *  Link state.
   */
  ABLLinkSessionStateRef ABLLinkCaptureAudioSessionState(ABLLinkRef);

  /*! @brief Commit the given session state to the Link session from the
   *  audio thread.
   *
   *  @discussion This function is lockfree and should ONLY be called
   *  in the audio thread. The given session state will replace the current
   *  Link session state. Modifications to the session based on the new
   *  session state will be communicated to other peers in the session.
   */
  void ABLLinkCommitAudioSessionState(ABLLinkRef, ABLLinkSessionStateRef);

  /*! @brief Capture the current Link session state from the main
   *  application thread.
   *
   *  @discussion This function provides the ability to query the Link
   *  session state from the main application thread and should only be
   *  used from that thread. The returned session state stores a snapshot
   *  of the current Link state, so it should be captured and used in
   *  a local scope. Storing the session state for later use in a different
   *  context is not advised because it will provide an outdated view
   *  on the Link state.
   */
  ABLLinkSessionStateRef ABLLinkCaptureAppSessionState(ABLLinkRef);

  /*! @brief Commit the session state to the Link session from the main
   *  application thread.
   *
   *  @discussion This function should ONLY be called in the main
   *  thread. The given session state will replace the current Link
   *  session state. Modifications to the session based on the new session
   *  state will be communicated to other peers in the session.
   */
  void ABLLinkCommitAppSessionState(ABLLinkRef, ABLLinkSessionStateRef);


  /*! @section ABLLinkSessionState functions
   *
   *  The following functions all query or modify aspects of a
   *  captured session state. Modifications made to a session state will
   *  never be seen by other peers in a session until they are committed
   *  using the appropriate function above.
   *
   *  Time value parameters for the following functions are specified
   *  as hostTimeAtOutput. Host time refers to the system time unit
   *  used by the mHostTime member of AudioTimeStamp and the
   *  mach_absolute_time function. hostTimeAtOutput refers to the host
   *  time at which a sound reaches the audio output of a device. In
   *  order to determine the host time at the device output, the
   *  AVAudioSession.outputLatency property must be taken into
   *  consideration along with any additional buffering latency
   *  introduced by the software.
   */

  /*! @brief The tempo of the given session state, in Beats Per Minute.
   *
   *  @discussion This is a stable value that is appropriate for display
   *  to the user. Beat time progress will not necessarily match this tempo
   *  exactly because of clock drift compensation.
   */
  double ABLLinkGetTempo(ABLLinkSessionStateRef);

  /*! @brief Set the tempo to the given bpm value at the given time.
   *
   * @discussion The change is applied immediately and sent to the network after
   * committing the session state.
   */
  void ABLLinkSetTempo(
    ABLLinkSessionStateRef,
    double bpm,
    uint64_t hostTimeAtOutput);

  /*! @brief: Get the beat value corresponding to the given host time
   *  for the given quantum.
   *
   *  @discussion: The magnitude of the resulting beat value is
   *  unique to this Link instance, but its phase with respect to
   *  the provided quantum is shared among all session
   *  peers. For non-negative beat values, the following
   *  property holds: fmod(ABLLinkBeatAtTime(tl, ht, q), q) ==
   *  ABLLinkPhaseAtTime(tl, ht, q).
   */
  double ABLLinkBeatAtTime(
    ABLLinkSessionStateRef,
    uint64_t hostTimeAtOutput,
    double quantum);

  /*! @brief Get the host time at which the sound corresponding to the
   *  given beat time and quantum reaches the device's audio output.
   *
   *  @discussion: The inverse of ABLLinkBeatAtTime, assuming
   *  a constant tempo.
   *
   *  ABLLinkBeatAtTime(tl, ABLLinkTimeAtBeat(tl, b, q), q) == b.
   */
  uint64_t ABLLinkTimeAtBeat(
    ABLLinkSessionStateRef,
    double beatTime,
    double quantum);

  /*! @brief Get the phase for a given beat time value on the shared
   *  beat grid with respect to the given quantum.
   *
   *  @discussion This function allows access to the phase
   *  of a host time as described above with respect to a quantum.
   *  The returned value will be in the range [0, quantum).
   */
  double ABLLinkPhaseAtTime(
    ABLLinkSessionStateRef,
    uint64_t hostTimeAtOutput,
    double quantum);

  /*! @brief: Attempt to map the given beat time to the given host
   *  time in the context of the given quantum.
   *
   *  @discussion: This function behaves differently depending on the
   *  state of the session. If no other peers are connected,
   *  then this instance is in a session by itself and is free to
   *  re-map the beat/time relationship whenever it pleases.
   *
   *  If there are other peers in the session, this instance
   *  should not abruptly re-map the beat/time relationship in the
   *  session because that would lead to beat discontinuities among
   *  the other peers. In this case, the given beat will be mapped
   *  to the next time value greater than the given time with the
   *  same phase as the given beat.
   *
   *  This function is specifically designed to enable the concept of
   *  "quantized launch" in client applications. If there are no other
   *  peers in the session, then an event (such as starting
   *  transport) happens immediately when it is requested. If there
   *  are other peers, however, we wait until the next time at which
   *  the session phase matches the phase of the event, thereby
   *  executing the event in-phase with the other peers in the
   *  session. The client only needs to invoke this method to
   *  achieve this behavior and should not need to explicitly check
   *  the number of peers.
   */
  void ABLLinkRequestBeatAtTime(
    ABLLinkSessionStateRef,
    double beatTime,
    uint64_t hostTimeAtOutput,
    double quantum);

  /*! @brief: Rudely re-map the beat/time relationship for all peers
   *  in a session.
   *
   *  @discussion: DANGER: This function should only be needed in
   *  certain special circumstances. Most applications should not
   *  use it. It is very similar to ABLLinkRequestBeatAtTime except that it
   *  does not fall back to the quantizing behavior when it is in a
   *  session with other peers. Calling this method will
   *  unconditionally map the given beat time to the given host time and
   *  broadcast the result to the session. This is very anti-social
   *  behavior and should be avoided.
   *
   *  One of the few legitimate uses of this method is to
   *  synchronize a Link session with an external clock source. By
   *  periodically forcing the beat/time mapping according to an
   *  external clock source, a peer can effectively bridge that
   *  clock into a Link session. Much care must be taken at the
   *  application layer when implementing such a feature so that
   *  users do not accidentally disrupt Link sessions that they may
   *  join.
   */
  void ABLLinkForceBeatAtTime(
    ABLLinkSessionStateRef,
    double beatTime,
    uint64_t hostTimeAtOutput,
    double quantum);

  /*! @brief: Set if transport should be playing or stopped at the given time. */
  void ABLLinkSetIsPlaying(
    ABLLinkSessionStateRef,
    bool isPlaying,
    uint64_t hostTimeAtOutput);

  /*! @brief: Is transport playing? */
  bool ABLLinkIsPlaying(ABLLinkSessionStateRef);

  /*! @brief: Get the time at which a transport start/stop occurs */
  uint64_t ABLLinkTimeForIsPlaying(ABLLinkSessionStateRef);

  /*! @brief: Convenience function to attempt to map the given beat to the time
   *  when transport is starting to play in context to the given quantum.
   *  This function evaluates to a no-op if ABLLinkIsPlaying() equals false.
   */
  void ABLLinkRequestBeatAtStartPlayingTime(
    ABLLinkSessionStateRef,
    double beatTime,
    double quantum);

  /*! @brief: Convenience function to start or stop transport at a given time and
   *  attempt to map the given beat to this time in context of the given quantum.
   */
  void ABLLinkSetIsPlayingAndRequestBeatAtTime(
    ABLLinkSessionStateRef,
    bool isPlaying,
    uint64_t hostTimeAtOutput,
    double beatTime,
    double quantum);

  /*! @brief Is audio sharing currently enabled?
   *
   *  @discussion Returns true if audio sharing is currently enabled.
   *  The audio sharing status is only controllable by the user via the
   *  Link settings view and is not controllable programmatically.
   *
   *  To expose the audio sharing toggle in the Link settings view, a
   *  Boolean entry with the key ABLLinkAudioSupported must be added to
   *  Info.plist and set to YES.
   *
   *  By adding a string entry with the key ABLLinkPeerName to Info.plist,
   *  a default local peer name for identification in the Link session can
   *  be set. If the entry is not present the app will be identified by
   *  the name "Link App". The effective peer name can be changed by the
   *  user via the Link settings view.
   */
  bool ABLLinkIsAudioEnabled(ABLLinkRef);

  /*! @brief Invoked on the main thread when the user changes the
   *  audio sharing enabled state via the Link settings view.
   */
  void ABLLinkSetIsAudioEnabledCallback(
    ABLLinkRef,
    ABLLinkIsAudioEnabledCallback callback,
    void* context);

  /*! @brief Reference to an audio sink instance.
   *
   *  @discussion An audio sink announces an audio channel to the Link
   *  session and can be used to send audio samples to other peers.
   */
  typedef struct ABLLinkAudioSink *ABLLinkAudioSinkRef;

  /*! @brief Reference to an audio sink buffer handle.
   *
   *  @discussion A buffer handle provides access to a buffer for writing
   *  audio samples that will be sent to other peers.
   */
  typedef struct ABLLinkAudioSinkBufferHandle *ABLLinkAudioSinkBufferHandleRef;

  /*! @brief Create a new audio sink with a name and maximum buffer size.
   *
   *  @param name The name of the audio channel, visible to other peers.
   *  @param maxNumSamples Maximum buffer size in samples. This should
   *  account for the number of channels times the number of samples per
   *  channel in one audio callback.
   *
   *  @discussion The announced channel is visible to other peers for the
   *  lifetime of the sink. Audio will only be sent if at least one peer
   *  in the session has requested it.
   */
  ABLLinkAudioSinkRef ABLLinkAudioSinkNew(
    ABLLinkRef,
    const char *name,
    uint32_t maxNumSamples);

  /*! @brief Destroy an audio sink and cleanup its associated resources.
   *
   *  @discussion After deletion, the audio channel will no longer be
   *  visible to other peers in the session.
   */
  void ABLLinkAudioSinkDelete(ABLLinkAudioSinkRef);

  /*! @brief Get the current maximum number of samples a buffer handle can hold.
   *
   *  @discussion This function is lockfree.
   */
  uint32_t ABLLinkAudioSinkMaxNumSamples(ABLLinkAudioSinkRef);

  /*! @brief Request a maximum buffer size for future buffers.
   *
   *  @discussion Increase the number of samples retained buffer handles
   *  can hold. If the requested number of samples is smaller than the
   *  current maximum number of samples this is a no-op. This function is
   *  lockfree.
   */
  void ABLLinkAudioSinkRequestMaxNumSamples(ABLLinkAudioSinkRef,
    uint32_t maxNumSamples);

  /*! @brief Retain a buffer for writing audio samples.
   *
   *  @discussion Only one buffer handle can be retained at a time. This
   *  function is lockfree. A buffer handle should never outlive the audio
   *  sink it was created from. Returns NULL if no corresponding source
   *  exists or no buffer is available.
   */
  ABLLinkAudioSinkBufferHandleRef ABLLinkAudioRetainBuffer(ABLLinkAudioSinkRef);

  /*! @brief Check if the buffer handle is valid.
   *
   *  @discussion Make sure to check this before using the handle. The
   *  handle may be invalid if no peer has currently requested audio from
   *  this sink or no buffer is available. This function is lockfree.
   */
  bool ABLLinkAudioSinkBufferHandleIsValid(ABLLinkAudioSinkBufferHandleRef);

  /*! @brief Get a pointer to the buffer for writing samples.
   *
   *  @discussion Audio buffers are interleaved and samples are represented
   *  as 16-bit signed integers. This function is lockfree.
   */
  int16_t *ABLLinkAudioSinkBufferSamples(ABLLinkAudioSinkBufferHandleRef);

  /*! @brief Commit the buffer after writing samples and release the handle.
   *
   *  @param sessionState The current Link session state.
   *  @param beatsAtBufferBegin Beat at the start of the buffer.
   *  @param quantum Quantum value for beat mapping.
   *  @param numFrames Number of frames written.
   *  @param numChannels Number of channels (1 for mono, 2 for stereo).
   *  @param sampleRate Sample rate in Hz.
   *  @return True if the buffer was successfully committed.
   *
   *  @discussion After calling this function, the buffer handle should not
   *  be used anymore. The Link session state, quantum, and beats at buffer
   *  begin must be the same as used for rendering the audio locally.
   *  Changes to the Link session state should always be made before
   *  rendering and eventually writing the buffer. numFrames * numChannels
   *  may not exceed maxNumSamples. This function is lockfree.
   */
  bool ABLLinkAudioReleaseAndCommitBuffer(ABLLinkAudioSinkRef,
    ABLLinkAudioSinkBufferHandleRef,
    ABLLinkSessionStateRef sessionState,
    double beatsAtBufferBegin,
    double quantum,
    uint32_t numFrames,
    uint32_t numChannels,
    uint32_t sampleRate);

  /*! @brief Release the buffer handle without committing.
   *
   *  @discussion Use this to release a buffer without sending it to other
   *  peers. After calling this function, the buffer handle should not be
   *  used anymore. This function is lockfree.
   */
  void ABLLinkAudioReleaseBuffer(ABLLinkAudioSinkBufferHandleRef);

  /*! @brief Configure audio properties from an AudioStreamBasicDescription.
   *
   *  @param asbd Pointer to an AudioStreamBasicDescription containing
   *  the audio format properties.
   *
   *  @discussion This is a convenience function for iOS/macOS to configure
   *  the audio sink with the properties from a Core Audio format description.
   */
  void ABLLinkSetPropertiesFromASBD(
      ABLLinkAudioSinkRef,
      const AudioStreamBasicDescription *asbd);

  /*! @brief Convenience function to commit a Core Audio buffer using beat time.
   *
   *  @param sink The audio sink to commit the buffer to.
   *  @param sessionState The current Link session state.
   *  @param beatsAtBufferBegin Beat at the start of the buffer.
   *  @param quantum Quantum value for beat mapping.
   *  @param numFrames Number of frames in the buffer.
   *  @param ioData Pointer to the AudioBufferList containing the audio data.
   *  @return True if the buffer was successfully committed.
   *
   *  @discussion This is a convenience function for iOS/macOS that directly
   *  commits audio data from a Core Audio AudioBufferList. The Link session
   *  state, quantum, and beats at buffer begin must be the same as used for
   *  rendering the audio locally. This function is lockfree.
   */
  bool ABLLinkCommitCoreAudioBufferWithBeats(
      ABLLinkAudioSinkRef sink,
      ABLLinkSessionStateRef sessionState,
      double beatsAtBufferBegin,
      double quantum,
      uint32_t numFrames,
      AudioBufferList *ioData);

  /*! @brief Convenience function to commit a Core Audio buffer using host time.
   *
   *  @param sink The audio sink to commit the buffer to.
   *  @param sessionState The current Link session state.
   *  @param hostTimeAtBufferBegin Host time at the start of the buffer.
   *  @param quantum Quantum value for beat mapping.
   *  @param numFrames Number of frames in the buffer.
   *  @param ioData Pointer to the AudioBufferList containing the audio data.
   *  @return True if the buffer was successfully committed.
   *
   *  @discussion This is a convenience function for iOS/macOS that directly
   *  commits audio data from a Core Audio AudioBufferList. The Link session
   *  state and quantum must be the same as used for rendering the audio
   *  locally. This function is lockfree.
   */
  bool ABLLinkCommitCoreAudioBufferWithHostTime(
      ABLLinkAudioSinkRef sink,
      ABLLinkSessionStateRef sessionState,
      uint64_t hostTimeAtBufferBegin,
      double quantum,
      uint32_t numFrames,
      AudioBufferList *ioData);

#ifdef __cplusplus
}
#endif
