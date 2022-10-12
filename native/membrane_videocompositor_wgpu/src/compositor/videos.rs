use wgpu::util::DeviceExt;

use super::colour_converters::YUVToRGBAConverter;
use super::textures::{RGBATexture, YUVTextures};
use super::{Point, Vertex};

#[derive(Debug, Clone, Copy)]
// All of the fields are in pixels, except of the `z`, which should be from the <0, 1> range
pub struct VideoPosition {
    /// Position in pixels.
    /// Specifying a position outside of the `output_caps`
    /// of the scene this will be rendered onto will cause it to not be displayed.
    pub top_left: Point<u32>,
    pub width: u32,
    pub height: u32,
    pub z: f32,
}

#[rustfmt::skip]
const INDICES: [u16; 6] = [
    0, 1, 3, 
    1, 2, 3
];

pub struct InputVideo {
    yuv_textures: YUVTextures,
    rgba_texture: RGBATexture,
    vertices: wgpu::Buffer,
    indices: wgpu::Buffer,
    position: VideoPosition,
}

impl InputVideo {
    pub fn new(
        device: &wgpu::Device,
        single_texture_bind_group_layout: &wgpu::BindGroupLayout,
        all_textures_bind_group_layout: &wgpu::BindGroupLayout,
        position: VideoPosition,
    ) -> Self {
        let yuv_textures = YUVTextures::new(
            device,
            position.width,
            position.height,
            wgpu::TextureUsages::COPY_DST | wgpu::TextureUsages::TEXTURE_BINDING,
            Some(single_texture_bind_group_layout),
            Some(all_textures_bind_group_layout),
        );

        let rgba_texture = RGBATexture::new(
            device,
            position.width,
            position.height,
            single_texture_bind_group_layout,
        );

        let vertices = device.create_buffer(&wgpu::BufferDescriptor {
            label: Some("video vertex buffer"),
            usage: wgpu::BufferUsages::VERTEX | wgpu::BufferUsages::COPY_DST,
            size: std::mem::size_of::<Vertex>() as u64 * 4,
            mapped_at_creation: false,
        });

        let indices = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
            label: Some("video index buffer"),
            contents: bytemuck::cast_slice(&INDICES),
            usage: wgpu::BufferUsages::INDEX,
        });

        Self {
            yuv_textures,
            rgba_texture,
            vertices,
            indices,
            position,
        }
    }

    pub fn upload_data(
        &self,
        device: &wgpu::Device,
        queue: &wgpu::Queue,
        converter: &YUVToRGBAConverter,
        data: &[u8],
    ) {
        self.yuv_textures.upload_data(queue, data);
        converter.convert(device, queue, &self.yuv_textures, &self.rgba_texture);
    }

    pub fn vertex_data(&self, output_caps: &crate::RawVideo) -> [Vertex; 4] {
        let scene_width = output_caps.width;
        let scene_height = output_caps.height;

        let position = self.position.top_left;
        let width = self.position.width;
        let height = self.position.height;

        let left = lerp(
            self.position.top_left.x as f64,
            0.0,
            scene_width as f64,
            -1.0,
            1.0,
        ) as f32;
        let right = lerp(
            (position.x + width) as f64,
            0.0,
            scene_width as f64,
            -1.0,
            1.0,
        ) as f32;
        let top = lerp(position.y as f64, 0.0, scene_height as f64, 1.0, -1.0) as f32;
        let bot = lerp(
            (position.y + height) as f64,
            0.0,
            scene_height as f64,
            1.0,
            -1.0,
        ) as f32;

        [
            Vertex {
                position: [right, top, self.position.z],
                texture_coords: [1.0, 0.0],
            },
            Vertex {
                position: [left, top, self.position.z],
                texture_coords: [0.0, 0.0],
            },
            Vertex {
                position: [left, bot, self.position.z],
                texture_coords: [0.0, 1.0],
            },
            Vertex {
                position: [right, bot, self.position.z],
                texture_coords: [1.0, 1.0],
            },
        ]
    }
}

impl<'a> InputVideo {
    pub fn draw(
        &'a self,
        queue: &wgpu::Queue,
        render_pass: &mut wgpu::RenderPass<'a>,
        output_caps: &crate::RawVideo,
    ) {
        queue.write_buffer(
            &self.vertices,
            0,
            bytemuck::cast_slice(&self.vertex_data(output_caps)),
        );

        render_pass.set_bind_group(
            0,
            self.rgba_texture.texture.bind_group.as_ref().unwrap(),
            &[],
        );
        render_pass.set_index_buffer(self.indices.slice(..), wgpu::IndexFormat::Uint16);
        render_pass.set_vertex_buffer(0, self.vertices.slice(..));

        let indices_len = (self.indices.size() / std::mem::size_of::<u16>() as u64) as u32;

        render_pass.draw_indexed(0..indices_len, 0, 0..1);
    }
}

/// Maps point `x` from the domain \[`x_min`, `x_max`\] to the point in the \[`y_min, y_max`\] line segment, using linear interpolation.
///
/// `x` outside the original domain will be extrapolated outside the target domain.
fn lerp(x: f64, x_min: f64, x_max: f64, y_min: f64, y_max: f64) -> f64 {
    (x - x_min) / (x_max - x_min) * (y_max - y_min) + y_min
}
