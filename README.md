PanamaKit
=========

iOS SDK for tempo syncing and exporting app content to Live

##Tempo Syncing

PanamaKit provides the capability to synchronize tempo and playback across multiple applications on multiple devices over a local wired or wifi network. This functionality is implemented by the **ABLSync** library.

###Shared Timeline
The central concept of the ABLSync library is the **shared timeline**. While MIDI clock sync only provides participating applications with a pulse, ABLSync maintains a distributed musical timeline that is shared by all participants. The units on the timeline correspond to 1/24th of a beat - the same subdivision used by MIDI clock sync.

The library synchronizes the position on the shared timeline as well as the tempo among all participants. This allows individual participants to join and leave the session or stop and start their own transport during a session without losing sync. Since the timeline is distributed amongst all participants, it will continue as long as any participant is still playing. This means that **there is no need to designate a participant as the Master** and the session can continue even after the first participant has left.

###Proposals
The distributed nature of the sync session means that all participants have the capability to make changes to the state of the session. Since these changes must be negotiated between participants, they cannot be guaranteed to succeed. Therefore, participants may **propose** changes to the session via the proposal functions in ABLSync.

Any participant can propose a tempo change, but the proposal may be rejected if another participant is currently modifying the shared tempo. This can be thought of as a *first touched first served* policy - for a limited window of time after a participant begins modifying the tempo, they have exclusive control over it.

Participants may also propose to start transport at a specified position on the shared timeline. If the shared timeline is not running (no other participants are playing) at the time of the proposal, such a proposal will succeed. But if the shared timeline is already running, the proposing participant will receive a start transport notification for the current position on the shared timeline, thereby joining in sync with the other participants.

![](/docs/diagrams/timeline.png)
<h6 align="center"> Figure 1: Transport proposals on the shared timeline </h6>

###Application Architecture
Applications that wish to participate in a distributed sync session must support receiving updates to their tempo and transport from other participants. In addition, they cannot assume that user actions that change tempo or transport can be fulfilled synchronously, as described in the Proposals section.

These requirements imply an asynchronous application architecture in which user actions are submitted and application state is only updated later via notifications. The ABLSync library supports this design by handling change proposals, invoking application callbacks when changes have been processed, and delivering the necessary application state to the audio processing thread. In addition, the current state of the session can always be queried by the application.

For consistency, it is recommended that applications use the proposal and callback mechanisms of the ABLSync library even when a network sync session is deactivated. In this case, the control flow remains the same but the latency of satisfying proposals will be reduced and proposals will not be rejected. This approach ensures that the same code pathways gets executed regardless of participation in a sync session.
