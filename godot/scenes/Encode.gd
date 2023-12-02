extends Spatial


# Declare member variables here. Examples:
# var a = 2
# var b = "text"

func subarray(a: PoolIntArray, start: int, end: int) -> PoolIntArray:
	var r: PoolIntArray
	r.resize(end-start+1)
	for i in range(start, end+1):
		r[i-start] = a[i]
	return r

# Called when the node enters the scene tree for the first time.
func _ready():
	var meshOptimizer: MeshOptimizer = MeshOptimizer.new()
	
	var testmesh: MeshInstance = get_node("TestMesh")
	var testmesh_lod0: MeshInstance = get_node("TestMesh_Lod0")
	var testmesh_lod1: MeshInstance = get_node("TestMesh_Lod1")
		
	var arrays: Array = testmesh.mesh.surface_get_arrays(0)
	var v := {
		"vertex_positions": arrays[Mesh.ARRAY_VERTEX],
		"vertex_normals": arrays[Mesh.ARRAY_NORMAL],
		"vertex_coords": PoolVector2Array(),
		"indices": arrays[Mesh.ARRAY_INDEX],
		"lods": PoolIntArray()
	}
	(testmesh.get_node("Label3D") as Label3D).text = "%d tris" % (arrays[Mesh.ARRAY_INDEX].size()/3)
	var result = meshOptimizer.simplify(v, PoolIntArray([5000, 250]), PoolRealArray([0.001, 0.02]))
	print("Vertices in: %d" % v["vertex_positions"].size())
	print("Vertices out: %d" % result["vertex_positions"].size())
	print("Indices in: %d" % v["indices"].size())
	print("Indices out: %d" % result["indices"].size())
	
	var indices: PoolIntArray = result["indices"]
	var lods: PoolIntArray = result["lods"]
	var indices_remapped = subarray(indices, 0, lods[0]-1)

	# Test compression
	var encoded: Dictionary = meshOptimizer.encode(result)
	print("Raw vertex array size: %d bytes" % [v["vertex_positions"].size()*3*4*2]) # vertices: 12 bytes position, 12 bytes normals
	print("Raw index array size: %d bytes" % [v["indices"].size()*4])
	print("Encoded vertex array size: %d bytes (%f bytes / vertex)" % [encoded["vertices"].size(), encoded["vertices"].size() / float(v["vertex_positions"].size())])
	print("Encoded index array size: %d bytes (%f bytes / tri)" % [encoded["indices"].size(), encoded["indices"].size() / (v["indices"].size() / 3.0)])
	
	var decoded: Dictionary =  meshOptimizer.decode(encoded)
	assert(decoded["vertex_positions"].size() == result["vertex_positions"].size())
	assert(decoded["indices"].size() == indices.size())
	
	var indices_decoded: PoolIntArray = decoded["indices"]
	var lods_decoded: PoolIntArray = decoded["lods"]
	var indices_remapped_decoded: PoolIntArray
	var indices_lod0_decoded: PoolIntArray
	var indices_lod1_decoded: PoolIntArray
	assert(lods_decoded.size() == 2)
	indices_remapped_decoded = subarray(indices_decoded, 0, lods_decoded[0]-1)
	indices_lod0_decoded = subarray(indices_decoded, lods_decoded[0], lods_decoded[1]-1)
	indices_lod1_decoded = subarray(indices_decoded, lods_decoded[1], indices_decoded.size()-1)

	var arrays_remapped_decoded: Array
	arrays_remapped_decoded.resize(ArrayMesh.ARRAY_MAX);
	arrays_remapped_decoded[ArrayMesh.ARRAY_INDEX] = indices_remapped_decoded
	arrays_remapped_decoded[ArrayMesh.ARRAY_VERTEX] = decoded["vertex_positions"]
	arrays_remapped_decoded[ArrayMesh.ARRAY_NORMAL] = decoded["vertex_normals"]
	var narr: ArrayMesh = ArrayMesh.new()
	narr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_remapped_decoded)
	testmesh.mesh = narr
	(testmesh.get_node("Label3D") as Label3D).text = "%d tris" % (indices_remapped_decoded.size()/3)

	var arrays_lod0_decoded: Array
	arrays_lod0_decoded.resize(ArrayMesh.ARRAY_MAX);
	arrays_lod0_decoded[ArrayMesh.ARRAY_INDEX] = indices_lod0_decoded
	arrays_lod0_decoded[ArrayMesh.ARRAY_VERTEX] = decoded["vertex_positions"]
	arrays_lod0_decoded[ArrayMesh.ARRAY_NORMAL] = decoded["vertex_normals"]
	var narr_lod0: ArrayMesh = ArrayMesh.new()
	narr_lod0.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_lod0_decoded)
	testmesh_lod0.mesh = narr_lod0
	(testmesh_lod0.get_node("Label3D") as Label3D).text = "%d tris" % (indices_lod0_decoded.size()/3)

	var arrays_lod1_decoded: Array
	arrays_lod1_decoded.resize(ArrayMesh.ARRAY_MAX);
	arrays_lod1_decoded[ArrayMesh.ARRAY_INDEX] = indices_lod1_decoded
	arrays_lod1_decoded[ArrayMesh.ARRAY_VERTEX] = decoded["vertex_positions"]
	arrays_lod1_decoded[ArrayMesh.ARRAY_NORMAL] = decoded["vertex_normals"]
	var narr_lod1: ArrayMesh = ArrayMesh.new()
	narr_lod1.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_lod1_decoded)
	testmesh_lod1.mesh = narr_lod1
	(testmesh_lod1.get_node("Label3D") as Label3D).text = "%d tris" % (indices_lod1_decoded.size()/3)
	
	var camera: Camera = get_node("Camera")
	camera.look_at(testmesh_lod0.translation + Vector3(0, 1, 0), Vector3.UP)
	


