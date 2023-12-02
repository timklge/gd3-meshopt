use gdnative::api::*;
use gdnative::prelude::*;
use meshopt::Vertex;

#[derive(Default, Clone)]
struct Mesh {
    vertices: Vec<Vertex>,
    indices: Vec<u32>,
}

#[derive(NativeClass)]
#[inherit(Node)]
#[register_with(Self::register_builder)]
pub struct MeshOptimizer {
    
}

#[derive(ToVariant, FromVariant)]
struct GodotMesh {
    vertex_positions: PoolArray<Vector3>,
    vertex_normals: PoolArray<Vector3>,
    vertex_coords: PoolArray<Vector2>,
    indices: PoolArray<i32>,
    lods: PoolArray<i32>,
}

#[derive(ToVariant, FromVariant)]
struct EncodedGodotMesh {
    indices: PoolArray<u8>,
    vertices: PoolArray<u8>,
    vertices_count: i32,
    index_count: i32,
    lods: PoolArray<i32>,
    error: String
}

impl GodotMesh {
    fn to_mesh(&self) -> Mesh {
        let mut vertices: Vec<Vertex> = Vec::with_capacity(self.vertex_positions.len() as usize);
        let mut indices: Vec<u32> = Vec::with_capacity(self.indices.len() as usize);

        let has_coords = !self.vertex_coords.is_empty();
        let has_normals = !self.vertex_normals.is_empty();

        for i in 0..self.vertex_positions.len(){
            let v = self.vertex_positions.get(i);
            let n = if has_normals { self.vertex_normals.get(i) } else { Vector3::new(0f32, 0f32, 0f32) };
            let t = if has_coords { self.vertex_coords.get(i) } else { Vector2::new(0f32, 0f32) };
            let vertex = Vertex { p: [v.x, v.y, v.z], n: [n.x, n.y, n.z], t: [t.x, t.y] };
            vertices.push(vertex);
        }

        for i in 0..self.indices.len(){
            indices.push(self.indices.get(i) as u32);
        }

        return Mesh{
            vertices,
            indices
        };
    }

    fn from_mesh(input: Mesh, input_lods: Vec<i32>) -> GodotMesh {
        let mut positions: PoolArray<Vector3> = PoolArray::new();
        let mut normals: PoolArray<Vector3> = PoolArray::new();
        let mut coords: PoolArray<Vector2> = PoolArray::new();
        let mut indices: PoolArray<i32> = PoolArray::new();
        let mut lods: PoolArray<i32> = PoolArray::new();

        positions.resize(input.vertices.len() as i32);
        normals.resize(input.vertices.len() as i32);
        coords.resize(input.vertices.len() as i32);
        indices.resize(input.indices.len() as i32);

        for (index, v) in input.vertices.iter().enumerate() {
            positions.set(index as i32, Vector3 { x: v.p[0].to_owned(), y: v.p[1].to_owned(), z: v.p[2].to_owned() });
            normals.set(index as i32, Vector3 { x: v.n[0], y: v.n[1], z: v.n[2] });
            coords.set(index as i32, Vector2 { x: v.t[0], y: v.t[1] });
        }

        for (index, v) in input.indices.iter().enumerate() {
            indices.set(index as i32, v.to_owned() as i32);
        }

        if !input_lods.is_empty() {
            lods.resize(input_lods.len() as i32);
            for (index, v) in input_lods.iter().enumerate() {
                lods.set(index as i32, v.to_owned() as i32);
            }
        }

        return GodotMesh {
            vertex_positions: positions,
            vertex_coords: coords,
            vertex_normals: normals,
            indices,
            lods
        };
    }
}

#[methods]
impl MeshOptimizer {
    fn register_builder(_builder: &ClassBuilder<Self>) {
        //godot_print!("MeshOptimizer builder is registered!");
    }

    fn new(_owner: &Node) -> Self {
        MeshOptimizer {
            
        }
    }

    fn remap_mesh(&self, mut mesh: Mesh) -> Mesh {
        let indices: Option<&[u32]> =  if !mesh.indices.is_empty() { Option::Some(&mesh.indices[..]) } else { None }; 
        
        let (total_vertices, vertex_remap) = meshopt::generate_vertex_remap(&mesh.vertices, indices);
        mesh.indices = meshopt::remap_index_buffer(indices, total_vertices, &vertex_remap[..]);
        mesh.vertices = meshopt::remap_vertex_buffer(&mesh.vertices[..], total_vertices, &vertex_remap[..]);

        mesh.indices = meshopt::optimize_vertex_cache(&mesh.indices[..], mesh.vertices.len());

        meshopt::optimize_overdraw_in_place_decoder(&mut mesh.indices, &mesh.vertices, 1.05f32);

        mesh.vertices = meshopt::optimize_vertex_fetch(&mut mesh.indices, &mesh.vertices);

        return mesh;
    }

    #[method]
    unsafe fn pass(&self, input: GodotMesh) -> GodotMesh {
        let mesh = input.to_mesh();
        return GodotMesh::from_mesh(mesh, Vec::new());
    }

    #[method]
    unsafe fn remap(&self, input: GodotMesh) -> GodotMesh {
        let mut mesh = input.to_mesh();
        mesh = self.remap_mesh(mesh);
        return GodotMesh::from_mesh(mesh, Vec::new());
    }

    #[method]
    unsafe fn simplify(&self, input: GodotMesh, target_count: PoolArray<i32>, target_error: PoolArray<f32>) -> GodotMesh {
        let mut mesh = input.to_mesh();
        mesh = self.remap_mesh(mesh);

        let mut lods: Vec<Vec<u32>> = Vec::new();
        for i in 0..target_count.len() {
            let indices = meshopt::simplify_decoder(&mesh.indices[..], &mesh.vertices[..], target_count.get(i) as usize, target_error.get(i));
            lods.push(indices);
        }
        let mut offset: i32 = mesh.indices.len() as i32;
        let mut offsets: Vec<i32> = Vec::with_capacity(lods.len());
        for i in 0..lods.len() {
            let indices = &lods[i];
            let mut optimized_indices = meshopt::optimize_vertex_cache(indices, mesh.vertices.len());
            meshopt::optimize_overdraw_in_place_decoder(&mut optimized_indices, &mesh.vertices, 1.05f32);
            offsets.push(offset);
            offset += optimized_indices.len() as i32;
            mesh.indices.append(&mut optimized_indices);
        }

        return GodotMesh::from_mesh(mesh, offsets);
    }

    #[method]
    unsafe fn simplify_sloppy(&self, input: GodotMesh, target_count: PoolArray<i32>) -> GodotMesh {
        let mut mesh = input.to_mesh();
        mesh = self.remap_mesh(mesh);

        let mut lods: Vec<Vec<u32>> = Vec::new();
        for i in 0..target_count.len() {
            let indices = meshopt::simplify_sloppy_decoder(&mesh.indices[..], &mesh.vertices[..], target_count.get(i) as usize);
            lods.push(indices);
        }
        let mut offset: i32 = mesh.indices.len() as i32;
        let mut offsets: Vec<i32> = Vec::with_capacity(lods.len());
        for i in 0..lods.len() {
            let indices = &lods[i];
            let mut optimized_indices = meshopt::optimize_vertex_cache(indices, mesh.vertices.len());
            meshopt::optimize_overdraw_in_place_decoder(&mut optimized_indices, &mesh.vertices, 1.05f32);
            offsets.push(offset);
            offset += optimized_indices.len() as i32;
            mesh.indices.append(&mut optimized_indices);
        }

        return GodotMesh::from_mesh(mesh, offsets);
    }
    
    #[method]
    unsafe fn encode(&self, input: GodotMesh) -> EncodedGodotMesh {
        let mut mesh = input.to_mesh();
        mesh = self.remap_mesh(mesh);

        let mut indices_result: PoolArray<u8> = PoolArray::new();
        let mut vertices_result: PoolArray<u8> = PoolArray::new();

        let vertices = meshopt::encode_vertex_buffer(&mesh.vertices);
        if vertices.is_err() {
            return EncodedGodotMesh {
                indices: indices_result,
                vertices: vertices_result,
                lods: input.lods,
                error: vertices.unwrap_err().to_string(),
                index_count: 0, vertices_count: 0
            }
        }
        
        let indices = meshopt::encode_index_buffer(&mesh.indices, mesh.vertices.len());
        if indices.is_err() {
            return EncodedGodotMesh {
                indices: indices_result,
                vertices: vertices_result,
                lods: input.lods,
                error: indices.unwrap_err().to_string(),
                index_count: 0, vertices_count: 0
            }
        }

        indices_result.append_vec(&mut indices.unwrap());
        vertices_result.append_vec(&mut vertices.unwrap());

        return EncodedGodotMesh {
            indices: indices_result,
            vertices: vertices_result,
            lods: input.lods,
            error: "".into(),
            index_count: mesh.indices.len() as i32,
            vertices_count: mesh.vertices.len() as i32
        }
    }

    #[method]
    unsafe fn decode(&self, input: EncodedGodotMesh) -> GodotMesh {
        let lods = input.lods.to_vec();

        let vertices_input: Vec<u8> = input.vertices.to_vec();
        let vertices_result = meshopt::decode_vertex_buffer(&vertices_input[..], input.vertices_count as usize);

        if vertices_result.is_err() {
            return GodotMesh::from_mesh(Mesh { vertices: Vec::new(), indices: Vec::new() }, lods);
        }

        let vertices = vertices_result.unwrap();
        let indices_input: Vec<u8> = input.indices.to_vec();
        let indices_result = meshopt::decode_index_buffer(&indices_input[..], input.index_count as usize);
        
        if indices_result.is_err() {
            return GodotMesh::from_mesh(Mesh { vertices: Vec::new(), indices: Vec::new() }, lods);
        }
        let indices = indices_result.unwrap();
        
        let mesh = Mesh {
            vertices,
            indices,
        };

        return GodotMesh::from_mesh(mesh, lods);
        
    }

}