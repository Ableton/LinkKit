/*! @file ABLLinkUtils.h
 *  @copyright 2018, Ableton AG, Berlin. All rights reserved.
 */

#pragma once

#include <Foundation/Foundation.h>
#include "ABLLink.h"

#ifdef __cplusplus
extern "C"
{
#endif

  /*! @brief Calculate the effective Beats Per Minute value for a range of beat values
   *  over the given number of samples at the given sample rate.
   */
  inline Float64 ABLLinkBpmInRange(
    const Float64 fromBeat,
    const Float64 toBeat,
    const UInt32 numSamples,
    const Float64 sampleRate) {
    return (toBeat - fromBeat) * sampleRate * 60 / numSamples;
  }

  /*! @brief Convert int16_t sample to int16_t (passthrough) */
  int16_t ABLConvertInt16(int16_t input);

  /*! @brief Convert uint16_t sample to int16_t (subtract DC offset) */
  int16_t ABLConvertUInt16(uint16_t input);

  /*! @brief Convert int32_t sample to int16_t (shift to 16-bit range) */
  int16_t ABLConvertInt32(int32_t input);

  /*! @brief Convert uint32_t sample to int16_t (subtract DC offset and shift) */
  int16_t ABLConvertUInt32(uint32_t input);

  /*! @brief Convert float sample to int16_t (range: -1.0 to 1.0) */
  int16_t ABLConvertFloat(float input);

#ifdef __cplusplus
}
#endif
