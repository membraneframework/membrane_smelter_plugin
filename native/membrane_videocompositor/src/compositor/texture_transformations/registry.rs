use std::{any::TypeId, collections::HashMap};

use super::{
    texture_transformation_pipeline::TextureTransformationPipeline, TextureTransformation,
};

pub struct TextureTransformationRegistry(HashMap<TypeId, TextureTransformationPipeline>);

impl TextureTransformationRegistry {
    pub fn new() -> Self {
        Self(HashMap::new())
    }

    pub fn register<T: TextureTransformation>(
        &mut self,
        device: &wgpu::Device,
        single_texture_bind_group_layout: &wgpu::BindGroupLayout,
    ) {
        let Self(map) = self;

        map.insert(
            TypeId::of::<T>(),
            TextureTransformationPipeline::new::<T>(device, single_texture_bind_group_layout),
        );
    }

    pub fn get(
        &self,
        transformation: &dyn TextureTransformation,
    ) -> &TextureTransformationPipeline {
        self.get_from_typeid(transformation.type_id())
    }

    fn get_from_typeid(&self, id: TypeId) -> &TextureTransformationPipeline {
        self.0.get(&id).expect(concat!(
            "Type",
            stringify!(T),
            "was never registered as a transformation"
        ))
    }
}
