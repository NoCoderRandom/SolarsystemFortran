import argparse
import os
import sys

import bpy
from mathutils import Vector


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        if block.users == 0:
            bpy.data.materials.remove(block)
    for block in bpy.data.images:
        if block.users == 0:
            bpy.data.images.remove(block)


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

    bpy.ops.object.select_all(action="DESELECT")
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    min_corner = [float("inf")] * 3
    max_corner = [float("-inf")] * 3
    for obj in meshes:
        for corner in obj.bound_box:
            world = obj.matrix_world @ Vector(corner)
            for i in range(3):
                min_corner[i] = min(min_corner[i], world[i])
                max_corner[i] = max(max_corner[i], world[i])

    center = [(min_corner[i] + max_corner[i]) * 0.5 for i in range(3)]
    extents = [max_corner[i] - min_corner[i] for i in range(3)]
    max_extent = max(extents)
    if max_extent <= 1.0e-8:
        raise RuntimeError("Imported mesh has invalid extent")

    scale = target_extent / max_extent
    for obj in meshes:
        obj.location.x -= center[0]
        obj.location.y -= center[1]
        obj.location.z -= center[2]
        obj.scale = (obj.scale[0] * scale, obj.scale[1] * scale, obj.scale[2] * scale)

    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def triangulate_meshes():
    meshes = find_mesh_objects()
    for obj in meshes:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.quads_convert_to_tris()
        bpy.ops.object.mode_set(mode="OBJECT")
        obj.select_set(False)


def unpack_and_repath_textures(output_dir):
    tex_dir = os.path.join(output_dir, "textures")
    os.makedirs(tex_dir, exist_ok=True)

    for image in bpy.data.images:
        if not image.filepath:
            continue
        image.filepath_raw = os.path.join(tex_dir, os.path.basename(bpy.path.abspath(image.filepath)))
        if image.packed_file is not None:
            image.save()
        else:
            src = bpy.path.abspath(image.filepath)
            if os.path.isfile(src):
                image.filepath = src
                image.unpack(method="USE_ORIGINAL") if image.packed_file else None

    for material in bpy.data.materials:
        if material.node_tree is None:
            continue
        for node in material.node_tree.nodes:
            if node.type == "TEX_IMAGE" and node.image is not None and node.image.filepath_raw:
                node.image.filepath = os.path.relpath(node.image.filepath_raw, output_dir)


def export_obj(output_path):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in find_mesh_objects():
        obj.select_set(True)
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

    output_dir = os.path.dirname(os.path.abspath(args.output))
    os.makedirs(output_dir, exist_ok=True)

    reset_scene()
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(args.input))
    decimate_meshes(args.decimate_ratio)
    triangulate_meshes()
    center_and_scale(args.target_extent)
    unpack_and_repath_textures(output_dir)
    export_obj(os.path.abspath(args.output))


if __name__ == "__main__":
    argv = sys.argv
    if "--" in argv:
        argv = argv[argv.index("--") + 1 :]
    else:
        argv = []
    main(argv)
