LinkKit
=========

iOS SDK for [Ableton Link](https://ableton.com/link), a **new technology** that **synchronizes musical beat, tempo,** and **phase** across multiple applications running on multiple devices. Applications on devices connected to a **local network** discover each other automatically and **form a musical session** in which each participant can **perform independently**: anyone can start or stop while still staying in time. Anyone can change the tempo, the **others will follow**. Anyone can **join** or **leave** without disrupting the session.

##License
Usage of LinkKit is governed by the [Ableton Link SDK license](Ableton_Link_SDK_License_v1.0.pdf).

##Conceptual Overview
Link is different from other approaches to synchronizing electronic instruments that you may be familiar with. It is not designed to orchestrate multiple instruments so that they play together in lock-step along a shared timeline. In fact, Link-enabled apps each have their own independent timelines. The Link library maintains a temporal relationship between these independent timelines that provides the experience of playing in time without the timelines being identical.

Playing "in time" is an intentionally vague term that might have different meanings for different musical contexts and different apps. As an app maker, you must decide the most natural way to map your app's musical concepts onto Link's synchronization model. For this reason, it's important to gain an intuitive understanding of how Link synchronizes **tempo**, **beat**, and **phase**.

###Tempo Synchronization
Tempo is a well understood parameter that represents the velocity of a beat timeline with respect to real time, giving it a unit of beats/time. Tempo synchronization is achieved when the beat timelines of all participants in a session are advancing at the same rate.

With Link, any participant can propose a change to the session tempo at any time. No single participant is responsible for maintaining the shared session tempo. Rather, each participant chooses to adopt the last tempo value that they've seen proposed on the network. This means that it is possible for participants' tempi to diverge during periods of tempo modification (especially during simultaneous modification by multiple participants), but this state is only temporary. The session will converge quickly to a common tempo after any modification. The Link approach to tempo relies on group adaptation to changes made by independent, autonomous actors - much like a group of traditional instrumentalists playing together.

###Beat Synchronization
At the most basic level, ABLLink provides the a shared pulse between instances and exposes this pulse to client apps. By aligning their musical beats with this pulse, apps can be assured that their beats will align with those of other participating apps. Apps can join and leave the session without stopping the music, the library aligns to the pulse stream of an existing session when joining.

###Shared Quantization
But simply playing beat-aligned may not be enough in many musical contexts. ABLLink also provides a shared reference grid for quantization, allowing apps to synchronize phase over durations longer or shorter than a single beat.

As an example, consider a case where two users both have a 4 beat loop in their respective apps. In this case playing "in time" may require more than simply aligning pulses. It may require synchronizing the phase of the loops, meaning that the first beats in each loop play together. In other cases, whole beat alignment may be too restrictive and prevent interesting musical interactions, such as playing upbeats or polyrhythms.

The ABLLink library facilitates these use cases by maintaining a beat quantization value that can be controlled by the client app. If this value is set to 1, then the library will implement simple beat synchronization - beats will be aligned between apps with no consideration for any larger musical structures (such as bars or loops). Values greater than 1 lead to phase synchronization across the number of beats specified. Values less than 1 result in sub-beat quantizaton. A value of 0 will result in no quantization, but tempo and pulse synchronization will remain in effect.

##Technical notes for integrators
###Integration concept###
Since the library must negotiate tempo, pulse, and quantization with other participants on the network, the app must defer control over these aspects of playback to the library. For each audio buffer, the integrating app must ask the library where it's supposed to be on the beat timeline by the end of that buffer. The app then figures out how it can render its buffer so as to get to that beat time. This could mean speeding up or slowing down or doing a beat time jump to get to the right position. The library does not specify *how* the app should get there, it just reports where it should be at a given time.

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
