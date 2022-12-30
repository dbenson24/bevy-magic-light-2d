#define_import_path bevy_2d_gi_experiment::gi_camera

struct CameraParams {
    screen_size:         vec2<f32>,
    screen_size_inv:     vec2<f32>,
    view_proj:           mat4x4<f32>,
    inverse_view_proj :  mat4x4<f32>,
    sdf_scale: vec2<f32>,
    inv_sdf_scale: vec2<f32>,
}

fn screen_to_ndc(
    screen_pose:     vec2<i32>,
    screen_size:     vec2<f32>,
    screen_size_inv: vec2<f32>) -> vec2<f32> {
    let screen_pose_f32 = vec2<f32>(0.0, screen_size.y)
                        + vec2<f32>(f32(screen_pose.x), f32(-screen_pose.y));
    return (screen_pose_f32 * screen_size_inv) * 2.0 - 1.0;
}

fn ndc_to_screen(ndc: vec2<f32>, screen_size: vec2<f32>) -> vec2<i32> {
    let screen_pose_f32 = (ndc + 1.0) * 0.5 * screen_size;
    return vec2<i32>(
        i32(screen_pose_f32.x),
        i32(screen_size.y - screen_pose_f32.y),
    );
}

fn screen_to_world(
    screen_pose:       vec2<i32>,
    screen_size:       vec2<f32>,
    inverse_view_proj: mat4x4<f32>,
    screen_size_inv:   vec2<f32>) -> vec2<f32> {
    return (inverse_view_proj * vec4<f32>(screen_to_ndc(screen_pose, screen_size, screen_size_inv), 0.0, 1.0)).xy;
}

fn world_to_ndc(
    world_pose:  vec2<f32>,
    view_proj:   mat4x4<f32>) -> vec2<f32> {
    return (view_proj * vec4<f32>(world_pose, 0.0, 1.0)).xy;
}

fn world_to_screen(
    world_pose:  vec2<f32>,
    screen_size: vec2<f32>,
    view_proj:   mat4x4<f32>) -> vec2<i32> {
    return ndc_to_screen(world_to_ndc(world_pose, view_proj), screen_size);
}

fn world_to_sdf_uv(world_pose: vec2<f32>, view_proj: mat4x4<f32>, inv_sdf_scale: vec2<f32>) -> vec2<f32> {
    let ndc = world_to_ndc(world_pose, view_proj);
    let ndc_sdf = ndc * inv_sdf_scale;
    let uv = (ndc_sdf + 1.0) * 0.5;
    let y = 1.0 - uv.y;
    return vec2<f32>(uv.x, y);
}

fn sdf_uv_to_world(uv: vec2<f32>, inverse_view_proj: mat4x4<f32>, sdf_scale: vec2<f32>) -> vec2<f32> {
    let y = 1.0 - uv.y;
    let uv = vec2<f32>(uv.x, y);
    let ndc_sdf = (uv * 2.0) - 1.0;
    let ndc = ndc_sdf * sdf_scale;
    return (inverse_view_proj * vec4<f32>(ndc, 0.0, 1.0)).xy;
}


fn bilinearFilter(texels: vec4<f32>, scaled_uv: vec2<f32>) -> f32 {
    let f = fract(scaled_uv - vec2<f32>(0.5));
    // let min_uv = floor(scaled_uv) + vec2<f32>(0.5);
    // let diff = scaled_uv - min_uv;
    // let max_uv = ceil(scaled_uv) + vec2<f32>(0.5);
    return mix(mix(texels.w, texels.z, f.x), mix(texels.x, texels.y, f.x), f.y);
}

fn bilinearSampleR(t: texture_2d<f32>, s: sampler, uv: vec2<f32>) -> f32 {
    // texels.x = -u, +v
    // texels.y = +u, +v,
    // texels.z = +u, -v,
    // texels.w = -u, -v
    let texels = textureGather(0, t, s, uv);
    // return texels.x;
    let dims = textureDimensions(t);
    let scaled_uv = uv * vec2<f32>(dims);
    return bilinearFilter(texels, scaled_uv);
}

fn bilinearSampleRGBA(t: texture_2d<f32>, s: sampler, uv: vec2<f32>) -> vec4<f32> {
    // texels.x = -u, +v
    // texels.y = +u, +v,
    // texels.z = +u, -v,
    // texels.w = -u, -v
    // return texels.x;
    let dims = textureDimensions(t);
    let scaled_uv = uv * vec2<f32>(dims);
    
    let r_texels = textureGather(0, t, s, uv);
    let r = bilinearFilter(r_texels, scaled_uv);
    let g_texels = textureGather(1, t, s, uv);
    let g = bilinearFilter(g_texels, scaled_uv);
    let b_texels = textureGather(2, t, s, uv);
    let b = bilinearFilter(b_texels, scaled_uv);
    let a_texels = textureGather(3, t, s, uv);
    let a = bilinearFilter(a_texels, scaled_uv);
    return vec4<f32>(r, g, b, a);
}