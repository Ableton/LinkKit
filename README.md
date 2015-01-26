PanamaKit
=========

iOS SDK for tempo syncing and exporting app content to Live

##Tempo Syncing

PanamaKit provides the capability to synchronize tempo and playback across multiple applications on multiple devices over a local wired or wifi network. This functionality is implemented by the **ABLSync** library.

###Shared Timeline
The central concept of the ABLSync library is the **shared timeline**. While MIDI clock sync only provides participating applications with a pulse, ABLSync maintains a distributed musical timeline that is shared by all participants. The units on the timeline correspond to 1/24th of a beat - the same subdivision used by MIDI clock sync.

The library synchronizes the position on the shared timeline as well as the tempo among all participants. This allows individual participants to join and leave the session or stop and start their own transport during a session without losing sync. Since the timeline is distributed amongst all participants, it will continue as long as any participant is still playing. This means that **no participant must be designated as the Master** and the session can continue even after the first participant has left.
