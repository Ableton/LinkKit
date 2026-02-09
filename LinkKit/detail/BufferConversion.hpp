// Copyright: 2026, Ableton AG, Berlin. All rights reserved.

#pragma once

#include "ableton/util/FloatIntConversion.hpp"
#include <cstdint>

namespace ableton::link_kit
{

// Convert int16_t sample (passthrough)
inline int16_t ConvertInt16(int16_t input)
{
  return input;
}

// Convert unsigned 16-bit sample (subtract DC offset)
inline int16_t ConvertUInt16(uint16_t input)
{
  return static_cast<int16_t>(static_cast<int32_t>(input) - 32768);
}

// Convert signed 32-bit sample (shift to 16-bit range)
inline int16_t ConvertInt32(int32_t input)
{
  return static_cast<int16_t>(input >> 16);
}

// Convert unsigned 32-bit sample (subtract DC offset and shift)
inline int16_t ConvertUInt32(uint32_t input)
{
  return static_cast<int16_t>((static_cast<int64_t>(input) - 2147483648LL) >> 16);
}

// Convert float sample (range: -1.0 to 1.0)
inline int16_t ConvertFloat(float input)
{
  return ableton::util::floatToInt16(input);
}

// Type-dispatched conversion helper
template <typename T>
int16_t Convert(T input);

template <>
inline int16_t Convert<int16_t>(int16_t input)
{
  return ConvertInt16(input);
}

template <>
inline int16_t Convert<uint16_t>(uint16_t input)
{
  return ConvertUInt16(input);
}

template <>
inline int16_t Convert<int32_t>(int32_t input)
{
  return ConvertInt32(input);
}

template <>
inline int16_t Convert<uint32_t>(uint32_t input)
{
  return ConvertUInt32(input);
}

template <>
inline int16_t Convert<float>(float input)
{
  return ConvertFloat(input);
}

// Copy mono buffer - converts samples from input type T to int16_t
template <typename T>
void CopyBufferMono(const uint32_t numFrames, const T* input, int16_t* output)
{
  for (uint32_t frame = 0; frame < numFrames; ++frame)
  {
    output[frame] = Convert<T>(input[frame]);
  }
}

// Copy stereo non-interleaved buffer - two separate arrays for left and right
template <typename T>
void CopyBufferStereoNonInterleaved(const uint32_t numFrames,
                                    const T* left,
                                    const T* right,
                                    int16_t* output)
{
  for (uint32_t frame = 0; frame < numFrames; ++frame)
  {
    output[2 * frame] = Convert<T>(left[frame]);
    output[2 * frame + 1] = Convert<T>(right[frame]);
  }
}

// Copy stereo interleaved buffer - left and right samples alternate in single
// array
template <typename T>
void CopyBufferStereoInterleaved(const uint32_t numFrames,
                                 const T* input,
                                 int16_t* output)
{
  for (uint32_t frame = 0; frame < numFrames * 2; ++frame)
  {
    output[frame] = Convert<T>(input[frame]);
  }
}

} // namespace ableton::link_kit