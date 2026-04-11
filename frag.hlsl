struct FragmentData
{
    int samplerIndex;
    int imageIndex;
};

struct PC
{
    FragmentData taskData;
    FragmentData meshData;
    FragmentData fragmentData;
};

[[vk::push_constant]]
ConstantBuffer<PC> pc;

// descriptor heap resources (bindless)
Texture2D imageHeap[] : register(t0, space0);
SamplerState samplerHeap[] : register(s0, space0);

struct PSInput
{
    float2 vUv : TEXCOORD0;
    float2 asdsa : TEXCOORD1;   // no exact perprimitive equivalent
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

PSOutput main(PSInput input)
{
    PSOutput o;

    ffff();

    int imageIndex   = pc.fragmentData.imageIndex;
    int samplerIndex = pc.fragmentData.samplerIndex;

    Texture2D tex = imageHeap[NonUniformResourceIndex(imageIndex)];
    SamplerState samp = samplerHeap[NonUniformResourceIndex(samplerIndex)];

    o.fragColor = tex.Sample(samp, input.vUv);

    return o;
}