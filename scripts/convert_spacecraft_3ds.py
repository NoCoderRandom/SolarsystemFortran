import argparse
import os
import sys

import bpy
from mathutils import Vector


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def find_mesh_objects():
    return [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]


def decimate_meshes(ratio):
    if ratio >= 0.999:
        return
    for obj in find_mesh_objects():
        modifier = obj.modifiers.new(name="DecimateRuntime", type="DECIMATE")
        modifier.ratio = ratio
        modifier.use_collapse_triangulate = True
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        obj.select_set(False)


def center_and_scale(target_extent):
    meshes = find_mesh_objects()
    if not meshes:
        raise RuntimeError("No mesh objects were imported")

    min_corner = [float("inf")] * 3
    max_corner = [float("-inf")] * 3
    for obj in meshes:
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            for i in range(3):
                min_corner[i] = min(min_corner[i], world[i])
                max_corner[i] = max(max_corner[i], world[i])

    center = [(min_corner[i] + max_corner[i]) * 0.5 for i in range(3)]
    max_extent = max(max_corner[i] - min_corner[i] for i in range(3))
    scale = target_extent / max_extent if max_extent > 1.0e-8 else 1.0

    for obj in meshes:
        obj.location.x -= center[0]
        obj.location.y -= center[1]
        obj.location.z -= center[2]
        obj.scale = (obj.scale[0] * scale, obj.scale[1] * scale, obj.scale[2] * scale)

    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def triangulate_meshes():
    for obj in find_mesh_objects():
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.quads_convert_to_tris()
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.select_set(False)


def export_obj(output_path):
    bpy.ops.object.select_all(action="DESELECT")
    meshes = find_mesh_objects()
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.wm.obj_export(
        filepath=output_path,
        export_selected_objects=True,
        export_materials=True,
        export_triangulated_mesh=True,
    )


def main(argv):
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--target-extent", type=float, default=2.0)
    parser.add_argument("--decimate-ratio", type=float, default=1.0)
    args = parser.parse_args(argv)

    reset_scene()
    bpy.ops.import_scene.autodesk_3ds(filepath=os.path.abspath(args.input))
    decimate_meshes(args.decimate_ratio)
    triangulate_meshes()
    center_and_scale(args.target_extent)
    os.makedirs(os.path.dirname(os.path.abspath(args.output)), exist_ok=True)
    export_obj(os.path.abspath(args.output))


if __name__ == "__main__":
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []
    main(argv)
