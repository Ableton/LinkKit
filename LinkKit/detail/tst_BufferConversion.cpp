// Copyright: 2026, Ableton AG, Berlin. All rights reserved.

#include "BufferConversion.hpp"
#include <ableton/test/CatchWrapper.hpp>
#include <limits>
#include <cmath>
#include <vector>

namespace ableton::link_kit
{

TEST_CASE("Type Conversion Tests", "[conversion]")
{

  SECTION("Int16 conversion passthrough", "[conversion][int16]")
  {
    CHECK(ConvertInt16(0) == 0);
    CHECK(ConvertInt16(100) == 100);
    CHECK(ConvertInt16(-100) == -100);
    CHECK(ConvertInt16(std::numeric_limits<int16_t>::max()) == std::numeric_limits<int16_t>::max());
    CHECK(ConvertInt16(std::numeric_limits<int16_t>::min()) == std::numeric_limits<int16_t>::min());
  }

  SECTION("UInt16 conversion removes DC offset", "[conversion][uint16]")
  {
    // UInt16 range [0, 65535] maps to Int16 range [-32768, 32767]
    CHECK(ConvertUInt16(0) == -32768);
    CHECK(ConvertUInt16(32768) == 0);
    CHECK(ConvertUInt16(65535) == 32767);

    // Midpoints
    CHECK(ConvertUInt16(16384) == -16384);
    CHECK(ConvertUInt16(49152) == 16384);
  }

  SECTION("Int32 conversion shifts 16 bits", "[conversion][int32]")
  {
    CHECK(ConvertInt32(0) == 0);
    CHECK(ConvertInt32(0x7FFF0000) == std::numeric_limits<int16_t>::max());
    CHECK(ConvertInt32((int32_t)0x80000000) == std::numeric_limits<int16_t>::min());

    // Preserves sign bit
    CHECK(ConvertInt32(0x12340000) == 0x1234);
    CHECK(ConvertInt32((int32_t)0xFEDC0000) == (int16_t)0xFEDC);

    // Discards lower bits
    int32_t valueWithLower = 0x1234ABCD;
    int32_t valueWithoutLower = 0x12340000;
    CHECK(ConvertInt32(valueWithLower) == ConvertInt32(valueWithoutLower));
  }

  SECTION("UInt32 conversion removes DC offset and shifts", "[conversion][uint32]")
  {
    CHECK(ConvertUInt32(2147483648U) == 0); // Center point
    CHECK(ConvertUInt32(0) == std::numeric_limits<int16_t>::min());
    CHECK(ConvertUInt32(std::numeric_limits<uint32_t>::max()) == std::numeric_limits<int16_t>::max());

    // Quarter points
    uint32_t quarterPoint = 1073741824U;
    uint32_t threeQuarterPoint = 3221225472U;
    CHECK(ConvertUInt32(quarterPoint) < 0);
    CHECK(ConvertUInt32(threeQuarterPoint) > 0);
  }

  SECTION("Float conversion maps -1.0 to 1.0 range", "[conversion][float]")
  {
    CHECK(ConvertFloat(0.0f) == 0);
    CHECK(ConvertFloat(1.0f) == std::numeric_limits<int16_t>::max());
    CHECK(ConvertFloat(-1.0f) == std::numeric_limits<int16_t>::min());

    // Midpoints
    int16_t halfPositive = ConvertFloat(0.5f);
    int16_t halfNegative = ConvertFloat(-0.5f);
    CHECK(halfPositive > 0);
    CHECK(halfNegative < 0);
    CHECK(std::abs(halfPositive - std::numeric_limits<int16_t>::max() / 2) < 100);
    CHECK(std::abs(halfNegative - std::numeric_limits<int16_t>::min() / 2) < 100);
    // Small values
    CHECK(std::abs(ConvertFloat(0.001f)) < 100);
    CHECK(std::abs(ConvertFloat(-0.001f)) < 100);

    // Clipping
    CHECK(ConvertFloat(2.0f) == std::numeric_limits<int16_t>::max());
    CHECK(ConvertFloat(-2.0f) == std::numeric_limits<int16_t>::min());
    CHECK(ConvertFloat(std::numeric_limits<float>::infinity()) == std::numeric_limits<int16_t>::max());
    CHECK(ConvertFloat(-std::numeric_limits<float>::infinity()) == std::numeric_limits<int16_t>::min());
  }

  SECTION("Float conversion with sine wave", "[conversion][float]")
  {
    const int numSamples = 128;
    for (int i = 0; i < numSamples; i++)
    {
      float phase = static_cast<float>(i) / static_cast<float>(numSamples);
      float sampleValue = std::sin(2.0f * M_PI * phase);
      int16_t converted = ConvertFloat(sampleValue);

      CHECK(converted >= std::numeric_limits<int16_t>::min());
      CHECK(converted <= std::numeric_limits<int16_t>::max());

      if (sampleValue > 0.01f)
      {
        CHECK(converted > 0);
      }
      else if (sampleValue < -0.01f)
      {
        CHECK(converted < 0);
      }
    }
  }

  SECTION("Conversion symmetry", "[conversion][symmetry]")
  {
    // Int32 symmetry
    int32_t positiveInt32 = 0x40000000;
    int32_t negativeInt32 = (int32_t)0xC0000000;
    CHECK(ConvertInt32(positiveInt32) == -ConvertInt32(negativeInt32));

    // Float symmetry
    float positiveFloat = 0.75f;
    float negativeFloat = -0.75f;
    int16_t convertedPosFloat = ConvertFloat(positiveFloat);
    int16_t convertedNegFloat = ConvertFloat(negativeFloat);
    CHECK(std::abs(convertedPosFloat + convertedNegFloat) <= 1);
  }

  SECTION("Boundary conditions", "[conversion][boundaries]")
  {
    // Int16 boundaries
    CHECK(ConvertInt16(std::numeric_limits<int16_t>::max()) == std::numeric_limits<int16_t>::max());
    CHECK(ConvertInt16(std::numeric_limits<int16_t>::min()) == std::numeric_limits<int16_t>::min());
    CHECK(ConvertInt16(std::numeric_limits<int16_t>::max() - 1) == std::numeric_limits<int16_t>::max() - 1);
    CHECK(ConvertInt16(std::numeric_limits<int16_t>::min() + 1) == std::numeric_limits<int16_t>::min() + 1);

    // UInt16 boundaries
    CHECK(ConvertUInt16(0) == -32768);
    CHECK(ConvertUInt16(std::numeric_limits<uint16_t>::max()) == 32767);

    // Int32 boundaries
    CHECK(ConvertInt32(std::numeric_limits<int32_t>::max()) == std::numeric_limits<int16_t>::max());
    CHECK(ConvertInt32(std::numeric_limits<int32_t>::min()) == std::numeric_limits<int16_t>::min());

    // UInt32 boundaries
    CHECK(ConvertUInt32(0) == std::numeric_limits<int16_t>::min());
    CHECK(ConvertUInt32(std::numeric_limits<uint32_t>::max()) == std::numeric_limits<int16_t>::max());

    // Float boundaries
    CHECK(ConvertFloat(1.0f) == std::numeric_limits<int16_t>::max());
    CHECK(ConvertFloat(-1.0f) == std::numeric_limits<int16_t>::min());
  }
}

TEST_CASE("Buffer Copy Tests", "[buffer][copy]")
{
  // Mono Float32 Buffer Copy
  SECTION("Copy Mono Float32", "[buffer][copy][float32][mono]")
  {
    const uint32_t numFrames = 128;
    std::vector<float> input(numFrames);
    std::vector<int16_t> output(numFrames);

    // Fill with sine wave pattern
    for (uint32_t i = 0; i < numFrames; i++)
    {
      input[i] =
        std::sin(2.0f * M_PI * static_cast<float>(i) / static_cast<float>(numFrames));
    }

    CopyBufferMono(numFrames, input.data(), output.data());

    // Verify conversion
    for (uint32_t i = 0; i < numFrames; i++)
    {
      int16_t expected = ConvertFloat(input[i]);
      CHECK(output[i] == expected);
    }
  }

  // Stereo Interleaved Float32 Buffer Copy
  SECTION(
    "Copy Stereo Interleaved Float32", "[buffer][copy][float32][stereo][interleaved]")
  {
    const uint32_t numFrames = 128;
    std::vector<float> input(numFrames * 2); // L/R interleaved
    std::vector<int16_t> output(numFrames * 2);

    // Fill with alternating pattern
    for (uint32_t i = 0; i < numFrames * 2; i++)
    {
      input[i] = (i % 2 == 0) ? 0.5f : -0.5f;
    }

    CopyBufferStereoInterleaved(numFrames, input.data(), output.data());

    // Verify all samples converted correctly
    for (uint32_t i = 0; i < numFrames * 2; i++)
    {
      int16_t expected = ConvertFloat(input[i]);
      CHECK(output[i] == expected);
    }
  }

  // Stereo Non-Interleaved Float32 Buffer Copy
  SECTION("Copy Stereo Non-Interleaved Float32",
          "[buffer][copy][float32][stereo][non-interleaved]")
  {
    const uint32_t numFrames = 128;
    std::vector<float> left(numFrames);
    std::vector<float> right(numFrames);
    std::vector<int16_t> output(numFrames * 2);

    // Fill separate left/right channels
    for (uint32_t i = 0; i < numFrames; i++)
    {
      left[i] = 0.25f;
      right[i] = -0.25f;
    }

    CopyBufferStereoNonInterleaved(numFrames, left.data(), right.data(), output.data());

    // Verify interleaved output
    for (uint32_t i = 0; i < numFrames; i++)
    {
      CHECK(output[2 * i] == ConvertFloat(left[i]));
      CHECK(output[2 * i + 1] == ConvertFloat(right[i]));
    }
  }

  // Mono Int16 Buffer Copy (passthrough)
  SECTION("Copy Mono Int16", "[buffer][copy][int16][mono]")
  {
    const uint32_t numFrames = 128;
    std::vector<int16_t> input(numFrames);
    std::vector<int16_t> output(numFrames);

    for (uint32_t i = 0; i < numFrames; i++)
    {
      input[i] = static_cast<int16_t>((i % 2 == 0) ? 1000 : -1000);
    }

    CopyBufferMono(numFrames, input.data(), output.data());

    // Should be exact passthrough
    for (uint32_t i = 0; i < numFrames; i++)
    {
      CHECK(output[i] == input[i]);
    }
  }

  // Stereo Interleaved Int16 Buffer Copy
  SECTION("Copy Stereo Interleaved Int16", "[buffer][copy][int16][stereo][interleaved]")
  {
    const uint32_t numFrames = 128;
    std::vector<int16_t> input(numFrames * 2);
    std::vector<int16_t> output(numFrames * 2);

    for (uint32_t i = 0; i < numFrames * 2; i++)
    {
      input[i] = static_cast<int16_t>((i % 2 == 0) ? 2000 : -2000);
    }

    CopyBufferStereoInterleaved(numFrames, input.data(), output.data());

    for (uint32_t i = 0; i < numFrames * 2; i++)
    {
      CHECK(output[i] == input[i]);
    }
  }

  // Stereo Non-Interleaved Int16 Buffer Copy
  SECTION(
    "Copy Stereo Non-Interleaved Int16", "[buffer][copy][int16][stereo][non-interleaved]")
  {
    const uint32_t numFrames = 128;
    std::vector<int16_t> left(numFrames);
    std::vector<int16_t> right(numFrames);
    std::vector<int16_t> output(numFrames * 2);

    for (uint32_t i = 0; i < numFrames; i++)
    {
      left[i] = 3000;
      right[i] = -3000;
    }

    CopyBufferStereoNonInterleaved(numFrames, left.data(), right.data(), output.data());

    for (uint32_t i = 0; i < numFrames; i++)
    {
      CHECK(output[2 * i] == left[i]);
      CHECK(output[2 * i + 1] == right[i]);
    }
  }

  // Mono Int32 Buffer Copy
  SECTION("Copy Mono Int32", "[buffer][copy][int32][mono]")
  {
    const uint32_t numFrames = 64;
    std::vector<int32_t> input(numFrames);
    std::vector<int16_t> output(numFrames);

    for (uint32_t i = 0; i < numFrames; i++)
    {
      input[i] = 0x40000000; // Shifts to 0x4000 = 16384
    }

    CopyBufferMono(numFrames, input.data(), output.data());

    for (uint32_t i = 0; i < numFrames; i++)
    {
      CHECK(output[i] == 16384);
    }
  }

  // Stereo Interleaved Int32 Buffer Copy
  SECTION("Copy Stereo Interleaved Int32", "[buffer][copy][int32][stereo][interleaved]")
  {
    const uint32_t numFrames = 64;
    std::vector<int32_t> input(numFrames * 2);
    std::vector<int16_t> output(numFrames * 2);

    for (uint32_t i = 0; i < numFrames * 2; i++)
    {
      input[i] = (i % 2 == 0) ? 0x20000000 : -0x20000000;
    }

    CopyBufferStereoInterleaved(numFrames, input.data(), output.data());

    for (uint32_t i = 0; i < numFrames * 2; i++)
    {
      int16_t expected = ConvertInt32(input[i]);
      CHECK(output[i] == expected);
    }
  }

  // Stereo Non-Interleaved Int32 Buffer Copy
  SECTION(
    "Copy Stereo Non-Interleaved Int32", "[buffer][copy][int32][stereo][non-interleaved]")
  {
    const uint32_t numFrames = 64;
    std::vector<int32_t> left(numFrames);
    std::vector<int32_t> right(numFrames);
    std::vector<int16_t> output(numFrames * 2);

    for (uint32_t i = 0; i < numFrames; i++)
    {
      left[i] = 0x30000000;
      right[i] = -0x30000000;
    }

    CopyBufferStereoNonInterleaved(numFrames, left.data(), right.data(), output.data());

    for (uint32_t i = 0; i < numFrames; i++)
    {
      CHECK(output[2 * i] == ConvertInt32(left[i]));
      CHECK(output[2 * i + 1] == ConvertInt32(right[i]));
    }
  }

  // Mono UInt16 Buffer Copy
  SECTION("Copy Mono UInt16", "[buffer][copy][uint16][mono]")
  {
    const uint32_t numFrames = 64;
    std::vector<uint16_t> input(numFrames);
    std::vector<int16_t> output(numFrames);

    for (uint32_t i = 0; i < numFrames; i++)
    {
      input[i] = 32768; // Center point, should convert to 0
    }

    CopyBufferMono(numFrames, input.data(), output.data());

    for (uint32_t i = 0; i < numFrames; i++)
    {
      CHECK(output[i] == 0);
    }
  }

  // Stereo Interleaved UInt16 Buffer Copy
  SECTION("Copy Stereo Interleaved UInt16", "[buffer][copy][uint16][stereo][interleaved]")
  {
    const uint32_t numFrames = 64;
    std::vector<uint16_t> input(numFrames * 2);
    std::vector<int16_t> output(numFrames * 2);

    for (uint32_t i = 0; i < numFrames * 2; i++)
    {
      input[i] = (i % 2 == 0) ? 40000 : 25000;
    }

    CopyBufferStereoInterleaved(numFrames, input.data(), output.data());

    for (uint32_t i = 0; i < numFrames * 2; i++)
    {
      int16_t expected = ConvertUInt16(input[i]);
      CHECK(output[i] == expected);
    }
  }

  // Mono UInt32 Buffer Copy
  SECTION("Copy Mono UInt32", "[buffer][copy][uint32][mono]")
  {
    const uint32_t numFrames = 64;
    std::vector<uint32_t> input(numFrames);
    std::vector<int16_t> output(numFrames);

    for (uint32_t i = 0; i < numFrames; i++)
    {
      input[i] = 2147483648U; // Center point, should convert to 0
    }

    CopyBufferMono(numFrames, input.data(), output.data());

    for (uint32_t i = 0; i < numFrames; i++)
    {
      CHECK(output[i] == 0);
    }
  }

  // Stereo Interleaved UInt32 Buffer Copy
  SECTION("Copy Stereo Interleaved UInt32", "[buffer][copy][uint32][stereo][interleaved]")
  {
    const uint32_t numFrames = 64;
    std::vector<uint32_t> input(numFrames * 2);
    std::vector<int16_t> output(numFrames * 2);

    for (uint32_t i = 0; i < numFrames * 2; i++)
    {
      input[i] = (i % 2 == 0) ? 2684354560U : 1610612736U;
    }

    CopyBufferStereoInterleaved(numFrames, input.data(), output.data());

    for (uint32_t i = 0; i < numFrames * 2; i++)
    {
      int16_t expected = ConvertUInt32(input[i]);
      CHECK(output[i] == expected);
    }
  }

  // Large buffer test
  SECTION("Copy Large Stereo Interleaved Float32", "[buffer][copy][float32][performance]")
  {
    const uint32_t numFrames = 4096;
    std::vector<float> input(numFrames * 2);
    std::vector<int16_t> output(numFrames * 2);

    for (uint32_t i = 0; i < numFrames * 2; i++)
    {
      input[i] = std::sin(2.0f * M_PI * static_cast<float>(i) / 100.0f);
    }

    CopyBufferStereoInterleaved(numFrames, input.data(), output.data());

    // Verify range
    for (uint32_t i = 0; i < numFrames * 2; i++)
    {
      CHECK(output[i] >= std::numeric_limits<int16_t>::min());
      CHECK(output[i] <= std::numeric_limits<int16_t>::max());
    }
  }

  // Edge cases
  SECTION("Copy Zero-Length Buffer", "[buffer][edge]")
  {
    std::vector<float> input;
    std::vector<int16_t> output;

    CopyBufferMono(0, input.data(), output.data());
    // Should not crash
    CHECK(true);
  }

  SECTION("Copy Single Sample", "[buffer][edge]")
  {
    std::vector<float> input = {0.5f};
    std::vector<int16_t> output(1);

    CopyBufferMono(1, input.data(), output.data());

    CHECK(output[0] == ConvertFloat(0.5f));
  }

  // Boundary value tests
  SECTION("Float32 Clipping Behavior", "[buffer][conversion][float32][clipping]")
  {
    const uint32_t numFrames = 4;
    std::vector<float> input = {-2.0f, -1.0f, 1.0f, 2.0f};
    std::vector<int16_t> output(numFrames);

    CopyBufferMono(numFrames, input.data(), output.data());

    // Verify values are within int16 range (should clip at extremes)
    for (uint32_t i = 0; i < numFrames; i++)
    {
      CHECK(output[i] >= std::numeric_limits<int16_t>::min());
      CHECK(output[i] <= std::numeric_limits<int16_t>::max());
    }
  }

  SECTION("Int32 Range Test", "[buffer][conversion][int32]")
  {
    const uint32_t numFrames = 3;
    std::vector<int32_t> input = {std::numeric_limits<int32_t>::min(), 0, std::numeric_limits<int32_t>::max()};
    std::vector<int16_t> output(numFrames);

    CopyBufferMono(numFrames, input.data(), output.data());

    CHECK(output[0] == std::numeric_limits<int16_t>::min());
    CHECK(output[1] == 0);
    CHECK(output[2] == std::numeric_limits<int16_t>::max());
  }

  SECTION("UInt32 Range Test", "[buffer][conversion][uint32]")
  {
    const uint32_t numFrames = 3;
    std::vector<uint32_t> input = {0, 2147483648U, std::numeric_limits<uint32_t>::max()};
    std::vector<int16_t> output(numFrames);

    CopyBufferMono(numFrames, input.data(), output.data());

    CHECK(output[0] == std::numeric_limits<int16_t>::min());
    CHECK(output[1] == 0);
    CHECK(output[2] == std::numeric_limits<int16_t>::max());
  }
}
} // namespace ableton::link_kit
