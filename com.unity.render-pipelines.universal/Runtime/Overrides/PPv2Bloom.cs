using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[Serializable, VolumeComponentMenu("Post-processing/PPv2 Bloom")]
public class PPv2Bloom : VolumeComponent, IPostProcessComponent
{
    [Tooltip("Strength of the bloom filter. Values higher than 1 will make bloom contribute more energy to the final render.")]
    public MinFloatParameter intensity = new MinFloatParameter(0f, 0f);

    [Tooltip("Filters out pixels under this level of brightness. Value is in gamma-space.")]
    public MinFloatParameter threshold = new MinFloatParameter(1f, 0f);

    [Tooltip("Makes transitions between under/over-threshold gradual. 0 for a hard threshold, 1 for a soft threshold).")]
    public ClampedFloatParameter softKnee = new ClampedFloatParameter(0.5f, 0f, 1f);

    [Tooltip("Clamps pixels to control the bloom amount. Value is in gamma-space.")]
    public FloatParameter clamp = new FloatParameter(65472f);

    [Tooltip("Distorts the bloom to give an anamorphic look. Negative values distort vertically, positive values distort horizontally.")]
    public ClampedFloatParameter anamorphicRatio = new ClampedFloatParameter(0f, -1f, 1f);

    [Tooltip("Global tint of the bloom filter.")]
    public ColorParameter color = new ColorParameter(Color.white, false, false, true);

    [Tooltip("Boost performance by lowering the effect quality. This settings is meant to be used on mobile and other low-end platforms but can also provide a nice performance boost on desktops and consoles.")]
    public BoolParameter fastMode = new BoolParameter(false);

    [Tooltip("The lens dirt texture used to add smudges or dust to the bloom effect.")]
    public TextureParameter dirtTexture = new TextureParameter(null);

    [Tooltip("The intensity of the lens dirtiness.")]
    public MinFloatParameter dirtIntensity = new MinFloatParameter(0f, 0f);

    [Tooltip("Max iteration count for both down-sampling and up-sampling.")]
    public ClampedIntParameter maxIteration = new ClampedIntParameter(16, 1, 16);


    // For URP uber shader...
    [Tooltip("Use bicubic sampling instead of bilinear sampling for the upsampling passes. This is slightly more expensive but helps getting smoother visuals.")]
    public BoolParameter highQualityFiltering = new BoolParameter(false);


    public bool IsActive() => intensity.value > 0f;

    public bool IsTileCompatible() => false;


    public enum Pass
    {
        Invalid = -1,

        Prefilter13,
        Prefilter4,
        Downsample13,
        Downsample4,
        UpsampleTent,
        UpsampleBox,
        //DebugOverlayThreshold,    // Remove debug functionalty for PPv2
        //DebugOverlayTent,         // Remove debug functionalty for PPv2
        //DebugOverlayBox           // Remove debug functionalty for PPv2
    }
}
