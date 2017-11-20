// Copyright: 2015, Ableton AG, Berlin. All rights reserved.

#pragma once

#ifdef __cplusplus
extern "C"
{
#endif

  /** Calculate the effective Beats Per Minute value for a range of beat values
      over the given number of samples at the given sample rate.
  */
  static inline double ABLLinkBpmInRange(
    const double fromBeat,
    const double toBeat,
    const uint32_t numSamples,
    const double sampleRate) {
    return (toBeat - fromBeat) * sampleRate * 60 / numSamples;
  }

#ifdef __cplusplus
}
#endif
