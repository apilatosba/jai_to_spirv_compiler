struct FragmentData {
    float4 color;
};

struct MeshData {
    float offset;
};

struct PushConstants {
    uint64_t taskData;     // Using uint64_t for buffer references
    MeshData* meshData;    // Slang supports native pointer syntax for Buffer References
    uint64_t fragmentData;
};

[vk::push_constant]
PushConstants pc;

[shader("mesh")]
[numthreads(1, 1, 1)]
[outputtopology("triangle")]
void main(
    out vertices float4 gl_Position[4],
    out indices uint3 gl_PrimitiveTriangleIndicesEXT[2],
    // Shared Location 0, Component 0 (Vertex)
    [vk::location(0), vk::component(0)] out vertices float2 uv[4],
    // Shared Location 0, Component 2 (Primitive)
    [vk::location(0), vk::component(2)] out primitives float2 rg[2]
)
{
    SetMeshOutputCounts(4, 2);

    // Positions
    gl_Position[0] = float4(-1, -1, 0.5, 1);
    gl_Position[1] = float4( 1, -1, 0.5, 1);
    gl_Position[2] = float4( 1,  1, 0.5, 1);
    gl_Position[3] = float4(-1,  1, 0.5, 1);

    // UVs (Per-Vertex)
    float offset = pc.meshData->offset;
    uv[0] = float2(0, 0 + offset);
    uv[1] = float2(1, 0 + offset);
    uv[2] = float2(1, 1 + offset);
    uv[3] = float2(0, 1 + offset);

    // RG (Per-Primitive)
    rg[0] = float2(1, 0);
    rg[1] = float2(0, 1);

    // Triangle Indices
    gl_PrimitiveTriangleIndicesEXT[0] = uint3(0, 1, 2);
    gl_PrimitiveTriangleIndicesEXT[1] = uint3(0, 2, 3);
}
