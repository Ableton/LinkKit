// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

#include "ABLSync.h"
#include <mach/mach_time.h>

#pragma once

#ifdef __cplusplus
extern "C"
{
#endif

  /** Calculate the effective Beats Per Minute value for a range of beat values
      over the given number of samples at the given sample rate.
  */
  inline Float64 ABLSyncBpmInRange(
    const Float64 fromBeat,
    const Float64 toBeat,
    const UInt32 numSamples,
    const Float64 sampleRate) {
    return (toBeat - fromBeat) * sampleRate * 60 / numSamples;
  }


  /** Calculate the next quantized beat time for a given quanta and beat time.

      If there is no active sync session, the beatTime argument will
      be returned unmodified.
  */
  inline Float64 ABLSyncNextQuantizedBeatTime(
    ABLSyncRef syncRef,
    const Float64 quantum,
    const Float64 beatTime) {
    const Float64 quantizedBeatTime = ABLSyncQuantizeBeatTime(syncRef, quantum, beatTime);
    return quantizedBeatTime >= beatTime ? quantizedBeatTime : quantizedBeatTime + quantum;
  }


  /** Calculate the previous quantized beat time for a given quanta and beat time.

      If there is no active sync session, the beatTime argument will
      be returned unmodified.
  */
  inline Float64 ABLSyncPreviousQuantizedBeatTime(
    ABLSyncRef syncRef,
    const Float64 quantum,
    const Float64 beatTime) {
    const Float64 quantizedBeatTime = ABLSyncQuantizeBeatTime(syncRef, quantum, beatTime);
    return quantizedBeatTime <= beatTime ? quantizedBeatTime : quantizedBeatTime - quantum;
  }

#ifdef __cplusplus
}
#endif
