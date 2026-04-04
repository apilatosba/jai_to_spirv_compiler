struct FragmentData {
    float4 color;
};

struct MeshData {
    float offset;
};

struct PushConstant {
    FragmentData* taskData; // Slang supports actual pointers
    MeshData* meshData;
    FragmentData* fragmentData;
};

// Define as a global Parameter Block or PushConstant
[[vk::push_constant]]
PushConstant pc;

struct MeshOutVertex {
    float2 uv;
    float4 color;
};

struct MeshOutPrimitive {
    float2 uv;
    float4 color;
};

struct B {
    float b;
};

struct A {
    B b;
};

[shader("mesh")]
[numthreads(1, 1, 1)]
[outputtopology("triangle")]
void main(
    out vertices MeshOutVertex mOutVertex[40],
    out indices uint3 mIndices[20],
    out primitives MeshOutPrimitive mOutPrimitive[20],
    // Built-in position is handled via SV_Position in the vertex struct
    // or by adding a specific output for it:
    out vertices float4 gl_Position[40] : SV_Position
) {
    // Equivalent to SetMeshOutputsEXT
    SetMeshOutputCounts(4, 2);

    A a;
    a.b.b = 40;

    gl_Position[0] = float4(-1, -1, 0.5, 1);
    gl_Position[1] = float4( 1, -1, 0.5, 1);
    gl_Position[2] = float4(1, 1, 0.5, 1);
    gl_Position[3] = float4(-1, 1, a.b.b, 1);

    // Accessing buffer pointers is direct
    float offset = pc.meshData.offset;

    mOutVertex[0].uv = float2(0, 0 + offset);
    mOutVertex[1].uv = float2(1, 0 + offset);
    mOutVertex[2].uv = float2(1, 1 + offset);
    mOutVertex[3].uv = float2(0, 1 + offset);

    mOutVertex[0].color = float4(1);

    mOutPrimitive[0].uv = float2(2);
    mOutPrimitive[0].color = float4(69);

    mIndices[0] = uint3(0, 1, 2);
    mIndices[1] = uint3(0, 2, 3);
}
