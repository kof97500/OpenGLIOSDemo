//
//  shader.metal
//  MetalDemo01
//
//  Created by Michael on 2019/6/17.
//  Copyright © 2019 Michael. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;
struct VertexOut
{
    float4 position [[position]];
    float2 textureCoordinate;
};
vertex VertexOut texture_vertex (
    constant float4*vertex_array[[buffer(0)]],
    constant float2*textureCoord_array[[buffer(1)]],
    unsigned int vid[[vertex_id]]){

    VertexOut outputVertices;

    outputVertices.position = vertex_array[vid];
    outputVertices.textureCoordinate = textureCoord_array[vid];

    return outputVertices;
}

fragment float4 texture_fragment(VertexOut fragmentInput [[stage_in]],
                                 texture2d<float> inputTexture [[texture(0)]]) {
    constexpr sampler quadSampler;
    float4 color = inputTexture.sample(quadSampler, fragmentInput.textureCoordinate);

    return color;
}
