using System.Linq;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace UnityEditor.Rendering.Universal
{
    [VolumeComponentEditor(typeof(PPv2Bloom))]
    sealed class PPv2BloomEditor : VolumeComponentEditor
    {
        SerializedDataParameter m_MaxIteration;
        SerializedDataParameter m_Intensity;
        SerializedDataParameter m_Threshold;
        SerializedDataParameter m_SoftKnee;
        SerializedDataParameter m_Clamp;
        SerializedDataParameter m_AnamorphicRatio;
        SerializedDataParameter m_Color;
        SerializedDataParameter m_FastMode;

        SerializedDataParameter m_DirtTexture;
        SerializedDataParameter m_DirtIntensity;

        public override void OnEnable()
        {
            var o = new PropertyFetcher<PPv2Bloom>(serializedObject);

            m_MaxIteration = Unpack(o.Find(x => x.maxIteration));
            m_Intensity = Unpack(o.Find(x => x.intensity));
            m_Threshold = Unpack(o.Find(x => x.threshold));
            m_SoftKnee = Unpack(o.Find(x => x.softKnee));
            m_Clamp = Unpack(o.Find(x => x.clamp));
            m_AnamorphicRatio = Unpack(o.Find(x => x.anamorphicRatio));
            m_Color = Unpack(o.Find(x => x.color));
            m_FastMode = Unpack(o.Find(x => x.fastMode));

            m_DirtTexture = Unpack(o.Find(x => x.dirtTexture));
            m_DirtIntensity = Unpack(o.Find(x => x.dirtIntensity));
        }

        public override void OnInspectorGUI()
        {
            if (UniversalRenderPipeline.asset?.postProcessingFeatureSet == PostProcessingFeatureSet.PostProcessingV2)
            {
                EditorGUILayout.HelpBox(UniversalRenderPipelineAssetEditor.Styles.postProcessingGlobalWarning, MessageType.Warning);
                return;
            }

            if (VolumeManager.instance != null && VolumeManager.instance.stack != null)
            {
                var urpBloom = VolumeManager.instance.stack.GetComponent<Bloom>();

                if (urpBloom != null && urpBloom.IsActive())
                {
                    EditorGUILayout.HelpBox("When Bloom is enable, PPv2 Bloom is not working!!", MessageType.Warning);
                }                
            }

            EditorGUILayout.LabelField("PPv2 Bloom", EditorStyles.miniLabel);

            PropertyField(m_MaxIteration);
            PropertyField(m_Intensity);
            PropertyField(m_Threshold);
            PropertyField(m_SoftKnee);
            PropertyField(m_Clamp);
            PropertyField(m_AnamorphicRatio);
            PropertyField(m_Color);
            PropertyField(m_FastMode);

            EditorGUILayout.LabelField("Lens Dirt", EditorStyles.miniLabel);

            PropertyField(m_DirtTexture);
            PropertyField(m_DirtIntensity);
        }
    }
}
