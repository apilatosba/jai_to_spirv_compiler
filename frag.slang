struct FragmentData
{
    int samplerIndex;
    int imageIndex;
};

[[vk::descriptor_heap]]
SamplerState samplerHeap[];

[[vk::descriptor_heap]]
Texture2D imageHeap[];

struct PC
{
    FragmentData taskData;
    FragmentData meshData;
    FragmentData fragmentData;
};

[[vk::push_constant]]
ConstantBuffer<PC> pc;

struct PSInput
{
    float2 vUv   : TEXCOORD0;
    float2 asdsa : TEXCOORD1;
};

struct PSOutput
{
    float4 fragColor : SV_Target0;
};

void ffff()
{
    int a = 10;
    a = a + a;
}

[shader("fragment")]
PSOutput main(PSInput input)
{
    PSOutput o;

    int imageIndex   = pc.fragmentData.imageIndex;
    int samplerIndex = pc.fragmentData.samplerIndex;

    Texture2D tex = imageHeap[NonUniformResourceIndex(imageIndex)];
    SamplerState samp = samplerHeap[NonUniformResourceIndex(samplerIndex)];

    o.fragColor = tex.Sample(samp, input.vUv);

    return o;
}