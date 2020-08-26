Shader "Hidden/Universal Render Pipeline/PPv2 Bloom"
{
    Properties
    {
        _MainTex("Source", 2D) = "white" {}
    }

    HLSLINCLUDE

        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
        #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Filtering.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"

        TEXTURE2D_X(_MainTex); SAMPLER(sampler_MainTex);
        TEXTURE2D_X(_BloomTex);
        //TEXTURE2D_X(_AutoExposureTex); // No auto exposure in URP

        float4 _MainTex_TexelSize;
        float  _SampleScale;
        //float4 _ColorIntensity; // Remove debug functionalty for PPv2
        float4 _Threshold; // x: threshold value (linear), y: threshold - knee, z: knee * 2, w: 0.25 / knee
        float4 _Params; // x: clamp, yzw: unused

        //
        // Quadratic color thresholding
        // curve = (threshold - knee, knee * 2, 0.25 / knee)
        //
        half4 QuadraticThreshold(half4 color, half threshold, half3 curve)
        {
            // Pixel brightness
            half br = Max3(color.r, color.g, color.b);

            // Under-threshold part: quadratic curve
            half rq = clamp(br - curve.x, 0.0, curve.y);
            rq = curve.z * rq * rq;

            // Combine and apply the brightness response curve.
            color *= max(rq, br - threshold) / max(br, 1.0e-4);

            return color;
        }

        // Better, temporally stable box filtering
        // [Jimenez14] http://goo.gl/eomGso
        // . . . . . . .
        // . A . B . C .
        // . . D . E . .
        // . F . G . H .
        // . . I . J . .
        // . K . L . M .
        // . . . . . . .
        half4 DownsampleBox13Tap(TEXTURE2D_PARAM(tex, samplerTex), float2 uv, float2 texelSize)
        {
            half4 A = SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + texelSize * float2(-1.0, -1.0)));
            half4 B = SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + texelSize * float2(0.0, -1.0)));
            half4 C = SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + texelSize * float2(1.0, -1.0)));
            half4 D = SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + texelSize * float2(-0.5, -0.5)));
            half4 E = SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + texelSize * float2(0.5, -0.5)));
            half4 F = SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + texelSize * float2(-1.0, 0.0)));
            half4 G = SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv));
            half4 H = SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + texelSize * float2(1.0, 0.0)));
            half4 I = SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + texelSize * float2(-0.5, 0.5)));
            half4 J = SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + texelSize * float2(0.5, 0.5)));
            half4 K = SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + texelSize * float2(-1.0, 1.0)));
            half4 L = SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + texelSize * float2(0.0, 1.0)));
            half4 M = SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + texelSize * float2(1.0, 1.0)));

            half2 div = (1.0 / 4.0) * half2(0.5, 0.125);

            half4 o = (D + E + I + J) * div.x;
            o += (A + B + G + F) * div.y;
            o += (B + C + H + G) * div.y;
            o += (F + G + L + K) * div.y;
            o += (G + H + M + L) * div.y;

            return o;
        }

        // Clamp HDR value within a safe range
        half4 SafeHDR(half4 c)
        {
            return min(c, 65504.0);
        }

        // Standard box filtering
        half4 DownsampleBox4Tap(TEXTURE2D_PARAM(tex, samplerTex), float2 uv, float2 texelSize)
        {
            float4 d = texelSize.xyxy * float4(-1.0, -1.0, 1.0, 1.0);

            half4 s;
            s = (SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + d.xy)));
            s += (SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + d.zy)));
            s += (SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + d.xw)));
            s += (SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + d.zw)));

            return s * (1.0 / 4.0);
        }

        // 9-tap bilinear upsampler (tent filter)
        half4 UpsampleTent(TEXTURE2D_PARAM(tex, samplerTex), float2 uv, float2 texelSize, float4 sampleScale)
        {
            float4 d = texelSize.xyxy * float4(1.0, 1.0, -1.0, 0.0) * sampleScale;

            half4 s;
            s = SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv - d.xy));
            s += SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv - d.wy)) * 2.0;
            s += SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv - d.zy));

            s += SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + d.zw)) * 2.0;
            s += SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv)) * 4.0;
            s += SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + d.xw)) * 2.0;

            s += SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + d.zy));
            s += SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + d.wy)) * 2.0;
            s += SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + d.xy));

            return s * (1.0 / 16.0);
        }

        // Standard box filtering
        half4 UpsampleBox(TEXTURE2D_PARAM(tex, samplerTex), float2 uv, float2 texelSize, float4 sampleScale)
        {
            float4 d = texelSize.xyxy * float4(-1.0, -1.0, 1.0, 1.0) * (sampleScale * 0.5);

            half4 s;
            s = (SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + d.xy)));
            s += (SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + d.zy)));
            s += (SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + d.xw)));
            s += (SAMPLE_TEXTURE2D_X(tex, samplerTex, (uv + d.zw)));

            return s * (1.0 / 4.0);
        }

        // ----------------------------------------------------------------------------------------
        // Prefilter

        half4 Prefilter(half4 color, float2 uv)
        {
            // No auto exposure in URP
            //half autoExposure = SAMPLE_TEXTURE2D_X(_AutoExposureTex, sampler_LinearClamp, uv).r;
            //color *= autoExposure;

            color = min(_Params.x, color); // clamp to max
            color = QuadraticThreshold(color, _Threshold.x, _Threshold.yzw);
            return color;
        }

        half4 FragPrefilter13(Varyings i) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
            float2 uv = UnityStereoTransformScreenSpaceTex(i.uv);
            half4 color = DownsampleBox13Tap(TEXTURE2D_ARGS(_MainTex, sampler_MainTex), uv, _MainTex_TexelSize.xy);
            return Prefilter(SafeHDR(color), uv);
        }

        half4 FragPrefilter4(Varyings i) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
            float2 uv = UnityStereoTransformScreenSpaceTex(i.uv);
            half4 color = DownsampleBox4Tap(TEXTURE2D_ARGS(_MainTex, sampler_MainTex), uv, _MainTex_TexelSize.xy);
            return Prefilter(SafeHDR(color), uv);
        }

        // ----------------------------------------------------------------------------------------
        // Downsample

        half4 FragDownsample13(Varyings i) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
            float2 uv = UnityStereoTransformScreenSpaceTex(i.uv);
            half4 color = DownsampleBox13Tap(TEXTURE2D_ARGS(_MainTex, sampler_MainTex), uv, _MainTex_TexelSize.xy);
            return color;
        }

        half4 FragDownsample4(Varyings i) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
            float2 uv = UnityStereoTransformScreenSpaceTex(i.uv);
            half4 color = DownsampleBox4Tap(TEXTURE2D_ARGS(_MainTex, sampler_MainTex), uv, _MainTex_TexelSize.xy);
            return color;
        }

        // ----------------------------------------------------------------------------------------
        // Upsample & combine

        half4 Combine(half4 bloom, float2 uv)
        {
            half4 color = SAMPLE_TEXTURE2D_X(_BloomTex, sampler_LinearClamp, uv);
            return bloom + color;
        }

        half4 FragUpsampleTent(Varyings i) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
            float2 uv = UnityStereoTransformScreenSpaceTex(i.uv);
            half4 bloom = UpsampleTent(TEXTURE2D_ARGS(_MainTex, sampler_MainTex), uv, _MainTex_TexelSize.xy, _SampleScale);
            return Combine(bloom, uv);
        }

        half4 FragUpsampleBox(Varyings i) : SV_Target
        {
            UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
            float2 uv = UnityStereoTransformScreenSpaceTex(i.uv);
            half4 bloom = UpsampleBox(TEXTURE2D_ARGS(_MainTex, sampler_MainTex), uv, _MainTex_TexelSize.xy, _SampleScale);
            return Combine(bloom, uv);
        }

        // Remove debug functionalty for PPv2
        // ----------------------------------------------------------------------------------------
        // Debug overlays

        //half4 FragDebugOverlayThreshold(Varyings i) : SV_Target
        //{
        //    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
        //    float2 uv = UnityStereoTransformScreenSpaceTex(i.uv);
        //    half4 color = SAMPLE_TEXTURE2D_X(_MainTex, sampler_LinearClamp, uv);
        //    return half4(Prefilter(color, uv).rgb, 1.0);
        //}

        //half4 FragDebugOverlayTent(Varyings i) : SV_Target
        //{
        //    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
        //    float2 uv = UnityStereoTransformScreenSpaceTex(i.uv);
        //    half4 bloom = UpsampleTent(TEXTURE2D_ARGS(_MainTex, sampler_MainTex), uv, _MainTex_TexelSize.xy, _SampleScale);
        //    return half4(bloom.rgb * _ColorIntensity.w * _ColorIntensity.rgb, 1.0);
        //}

        //half4 FragDebugOverlayBox(Varyings i) : SV_Target
        //{
        //    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);
        //    float2 uv = UnityStereoTransformScreenSpaceTex(i.uv);
        //    half4 bloom = UpsampleBox(TEXTURE2D_ARGS(_MainTex, sampler_MainTex), uv, _MainTex_TexelSize.xy, _SampleScale);
        //    return half4(bloom.rgb * _ColorIntensity.w * _ColorIntensity.rgb, 1.0);
        //}

    ENDHLSL

    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        // 0: Prefilter 13 taps
        Pass
        {
            HLSLPROGRAM

                #pragma vertex Vert
                #pragma fragment FragPrefilter13

            ENDHLSL
        }

        // 1: Prefilter 4 taps
        Pass
        {
            HLSLPROGRAM

                #pragma vertex Vert
                #pragma fragment FragPrefilter4

            ENDHLSL
        }

        // 2: Downsample 13 taps
        Pass
        {
            HLSLPROGRAM

                #pragma vertex Vert
                #pragma fragment FragDownsample13

            ENDHLSL
        }

        // 3: Downsample 4 taps
        Pass
        {
            HLSLPROGRAM

                #pragma vertex Vert
                #pragma fragment FragDownsample4

            ENDHLSL
        }

        // 4: Upsample tent filter
        Pass
        {
            HLSLPROGRAM

                #pragma vertex Vert
                #pragma fragment FragUpsampleTent

            ENDHLSL
        }

        // 5: Upsample box filter
        Pass
        {
            HLSLPROGRAM

                #pragma vertex Vert
                #pragma fragment FragUpsampleBox

            ENDHLSL
        }

        // Remove debug functionalty for PPv2
        //// 6: Debug overlay (threshold)
        //Pass
        //{
        //    HLSLPROGRAM

        //        #pragma vertex Vert
        //        #pragma fragment FragDebugOverlayThreshold

        //    ENDHLSL
        //}

        //// 7: Debug overlay (tent filter)
        //Pass
        //{
        //    HLSLPROGRAM

        //        #pragma vertex Vert
        //        #pragma fragment FragDebugOverlayTent

        //    ENDHLSL
        //}

        //// 8: Debug overlay (box filter)
        //Pass
        //{
        //    HLSLPROGRAM

        //        #pragma vertex Vert
        //        #pragma fragment FragDebugOverlayBox

        //    ENDHLSL
        //}
    }
}
