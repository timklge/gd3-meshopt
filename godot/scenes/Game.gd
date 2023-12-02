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
	var testmesh: MeshInstance = get_node("TestMesh")
	var testmesh_lod0: MeshInstance = get_node("TestMesh_Lod0")
	var testmesh_lod1: MeshInstance = get_node("TestMesh_Lod1")
		
	var camera: Camera = get_node("Camera")
	camera.look_at(testmesh_lod0.translation + Vector3(0, 1, 0), Vector3.UP)
	
	var meshOptimizer: MeshOptimizer = MeshOptimizer.new()
		
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
	
	var indices_lod0: PoolIntArray
	var indices_lod1: PoolIntArray
	assert(lods.size() == 2)
	indices_remapped = subarray(indices, 0, lods[0]-1)
	indices_lod0 = subarray(indices, lods[0], lods[1]-1)
	indices_lod1 = subarray(indices, lods[1], indices.size()-1)

	var arrays_remapped: Array
	arrays_remapped.resize(ArrayMesh.ARRAY_MAX);
	arrays_remapped[ArrayMesh.ARRAY_INDEX] = indices_remapped
	arrays_remapped[ArrayMesh.ARRAY_VERTEX] = result["vertex_positions"]
	arrays_remapped[ArrayMesh.ARRAY_NORMAL] = result["vertex_normals"]
	var narr: ArrayMesh = ArrayMesh.new()
	narr.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_remapped)
	testmesh.mesh = narr
	(testmesh.get_node("Label3D") as Label3D).text = "%d tris" % (indices_remapped.size()/3)

	var arrays_lod0: Array
	arrays_lod0.resize(ArrayMesh.ARRAY_MAX);
	arrays_lod0[ArrayMesh.ARRAY_INDEX] = indices_lod0
	arrays_lod0[ArrayMesh.ARRAY_VERTEX] = result["vertex_positions"]
	arrays_lod0[ArrayMesh.ARRAY_NORMAL] = result["vertex_normals"]
	var narr_lod0: ArrayMesh = ArrayMesh.new()
	narr_lod0.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_lod0)
	testmesh_lod0.mesh = narr_lod0
	(testmesh_lod0.get_node("Label3D") as Label3D).text = "%d tris" % (indices_lod0.size()/3)

	var arrays_lod1: Array
	arrays_lod1.resize(ArrayMesh.ARRAY_MAX);
	arrays_lod1[ArrayMesh.ARRAY_INDEX] = indices_lod1
	arrays_lod1[ArrayMesh.ARRAY_VERTEX] = result["vertex_positions"]
	arrays_lod1[ArrayMesh.ARRAY_NORMAL] = result["vertex_normals"]
	var narr_lod1: ArrayMesh = ArrayMesh.new()
	narr_lod1.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays_lod1)
	testmesh_lod1.mesh = narr_lod1
	(testmesh_lod1.get_node("Label3D") as Label3D).text = "%d tris" % (indices_lod1.size()/3)
	

