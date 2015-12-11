LinkKit
=========

iOS SDK for [Ableton Link](https://ableton.com/link), a **new technology** that **synchronizes musical beat, tempo,** and **phase** across multiple applications running on multiple devices. Applications on devices connected to a **local network** discover each other automatically and **form a musical session** in which each participant can **perform independently**: anyone can start or stop while still staying in time. Anyone can change the tempo, the **others will follow**. Anyone can **join** or **leave** without disrupting the session.

##License
Usage of LinkKit is governed by the [Ableton Link SDK license](Ableton_Link_SDK_License_v1.0.pdf).

##Conceptual Overview
Link is different from other approaches to synchronizing electronic instruments that you may be familiar with. It is not designed to orchestrate multiple instruments so that they play together in lock-step along a shared timeline. In fact, Link-enabled apps each have their own independent timelines. The Link library maintains a temporal relationship between these independent timelines that provides the experience of playing in time without the timelines being identical.

Playing "in time" is an intentionally vague term that might have different meanings for different musical contexts and different apps. As an app maker, you must decide the most natural way to map your app's musical concepts onto Link's synchronization model. For this reason, it's important to gain an intuitive understanding of how Link synchronizes **tempo**, **beat**, and **phase**.

####Tempo Synchronization
Tempo is a well understood parameter that represents the velocity of a beat timeline with respect to real time, giving it a unit of beats/time. Tempo synchronization is achieved when the beat timelines of all participants in a session are advancing at the same rate.

With Link, any participant can propose a change to the session tempo at any time. No single participant is responsible for maintaining the shared session tempo. Rather, each participant chooses to adopt the last tempo value that they've seen proposed on the network. This means that it is possible for participants' tempi to diverge during periods of tempo modification (especially during simultaneous modification by multiple participants), but this state is only temporary. The session will converge quickly to a common tempo after any modification. The Link approach to tempo relies on group adaptation to changes made by independent, autonomous actors - much like a group of traditional instrumentalists playing together.

####Beat Alignment
It's conceivable that for certain musical situations, participants would wish to only synchronize tempo and not other musical parameters. But for the vast majority of cases, playing with synchronized tempo in the absence of beat alignment would not be perceived as playing "in time." In this scenario, participants' beat timelines would advance at the same rate, but the relationship between values on those beat timelines would be undefined (i.e. Beat 1 on one participant's timeline might correspond to beat 3.23 on another's).

In most cases, we want to provide a stronger timing property for a session than just tempo synchronization - we also want beat alignment. When a session is in a state of beat alignment, an integral value on any participant's beat timeline corresponds to an integral value on all other participants' beat timelines. This property says nothing about the magnitude of beat values on each timeline, which can be different, just that any two timelines must only differ by an integral offset. For example, beat 1 on one participant's timeline might correspond to beat 3 or beat 4 on another's, but it cannot correspond to beat 3.5.

Note that in order for a session to be in a state of beat alignment, it must have synchronized tempo. Tempo determines beat length and beat length equivalence among all timelines is a pre-requisite for beat alignment.

####Phase Synchronization
Beat alignment is a necessary condition for playing "in time" in most circumstances, but it's often not enough. When only beat alignment is provided, the user may still not have their timing expectations met if they are working with larger musical constructs, such as bars and loops, that span multiple beats. In this case, they may expect that the beat position within such a construct (the phase) be synchronized, resulting in alignment of bar and loop boundaries across participants.

In order to enable the desired bar and loop alignment, app makers provide a quantum value to Link that specifies, in beats, the desired unit of phase synchronization. Link guarantees that session participants with the same quantum value will be phase aligned, meaning that if two participants have a 4 beat quantum, beat 3 on one participant's timeline could correspond to beat 11 on another's, but not beat 12. It also guarantees the expected relationship between sessions in which one participant has a multiple of another's quantum. So if one app has an 8-beat loop with a quantum of 8 and another has a 4-beat loop with a quantum of 4, then the beginning of an 8-beat loop will always correspond to the beginning of a 4-beat loop, whereas a 4-beat loop may align with the beginning or the middle of an 8-beat loop.

Specifying the quantum value and the handling of phase synchronization is the aspect of Link integration that leads to the greatest diversity of approaches among app makers. There's no one-size-fits-all recommendation about how to do this, it is very app-specific. Some apps have a constant quantum that never changes. Others allow it to change to match a changing value in their app, such as loop length or time signature. In Ableton Live, it is directly tied to the "Global Quantization" control, so it may be useful to explore how different values affect the behavior of Live in order to gain intuition about the quantum.

A decision that nearly all apps have to make is how phase synchronization affects the user action of starting to play. Live and the vast majority of apps perform a quantized launch, meaning that the user sees some sort of count-in animation or flashing play button until starting at the next quantum boundary. This is a very satisfying interaction because it allows multiple users on different devices to start exactly together just by pressing play at roughly the same time. However, there are other approaches imagineable, such as starting immediately while teleporting the playhead to the correct phase within the current loop or bar. The strategy that sticks as close to the spirit of the app is probably the right one.

A final note on phase synchronization: notice that it is more fundamental than beat alignment. There is in fact no special handling of beat alignment in Link. It is a property that emerges from synchronizing phase with a non-zero integral quantum value. This is worth noting because it is also possible to abandon beat alignment (perhaps to achieve polyrhythms) by specifying non-integral quantum values. A quantum value of 0 results in no phase synchronization at all and therefore no beat alignment. So it's easy to create the tempo-only synchronization scenario described previously in the [Beat Alignment](#beat-alignment) section if you can find a use for it.

##Technical notes for integrators
###Integration concept###
Since the library must negotiate tempo and quantization with other participants on the network, the app must defer control over these aspects of playback to the library. For each audio buffer, the integrating app must ask the library where it's supposed to be on the beat timeline by the end of that buffer. The app then figures out how it can render its buffer so as to get to that beat time. This could mean speeding up or slowing down or doing a beat time jump to get to the right position. The library does not specify *how* the app should get there, it just reports where it should be at a given time.

When there are no other participants on the network, or if syncing is disabled, it's guaranteed that no quantization is applied and tempo proposals are handled immediately. This means that client code in the audio callback should call the same ABLLink functions in all cases. There is no need (and it will almost certainly introduce bugs) to try to only use the library functions in the audio callback when syncing is enabled or there are other participants in a session.

###Host and beat times###
The ABLLink API deals with two time coordinate systems: host time and beat time. Establishing a bidirectional mapping between these coordinate systems is one of the primary functions of the library.

Host time as used in the API always refers to the system host time and is the same coordinate system as values returned by [`mach_absolute_time`](https://developer.apple.com/library/mac/qa/qa1398/_index.html) and the `mHostTime` field of the `AudioTimeStamp` structure.

Beat time as used in the API refers to a coordinate system in which integral values represent beats. The library maintains a beat timeline, which starts at zero when the library is initialized and runs continuously at a rate defined by the session tempo. Clients may sample this beat timeline at a given host time via the `ABLLinkBeatTimeAtHostTime` function. Clients may reset this beat time to a chosen value via the `ABLLinkResetBeatTime` function, which is useful for aligning the values on the library's beat timeline to the values on a client app's transport timeline.

###Host time at speaker output###
All host time values used in the ABLLink API refer to host times at speaker output. This is the important value for the library to know, since it must coordinate the timelines of multiple devices such that the same beat times are hitting the speakers of those devices at the same moment. This is made more complicated by the fact that different devices (and even the same device in different configurations) can have different output latencies.

In the audio callback, the system provides an `AudioTimeStamp` value for the audio buffer. The `mHostTime` field of this structure represents the host time at which the audio buffer will be passed to the hardware for output. Adding the output latency (see `AVAudioSession.outputLatency`) to this value will generally result in the correct host time at speaker output for the *beginning* of that buffer. To get the host time at speaker output for the end of the buffer, you would just add the buffer duration. For an example of this calculation, see the [LinkHut example project](examples/LinkHut/LinkHut/AudioEngine.m).

Note that if your app adds additional software latency, you will need to add this as well in the calculation of the host time at speaker output.

###App life cycle###
In order to provide the best user experience across the ecosystem of Link-enabled apps, it's important that apps take a consistent approach towards Link with regards to life cycle management. Furthermore, since the ABLLink library does not have access to all of the necessary information to correctly respond to life cycle events, app developers must follow the life cycle guidelines below in order to meet user expectations. Please consider these carefully.

- When an app moves to the background and it is known that no audio will be generated by the app while in the background, Link should be deactivated by calling `ABLLinkSetActive(false)`. This helps prevent the confusing situation where a silent background app discovers and connects to other Link enabled apps and devices.
- When an app is active, the ABLLink instance should be active. If an app deactivates Link using the `ABLLinkSetActive` function when going to the background, it must re-activate Link when becoming active again. For this reason, it is recommended that a call to `ABLLinkSetActive(true)` be included in the `applicationDidBecomeActive` method of the application delegate. Calling this function when Link is already active causes no harm, so this can be included unconditionally.

Please see the LinkHut [AppDelegate.m](examples/LinkHut/LinkHut/AppDelegate.m) file for an example implementation of these guidelines.
