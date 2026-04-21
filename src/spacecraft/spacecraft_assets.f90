module spacecraft_assets_mod
    use, intrinsic :: iso_c_binding, only: c_float, c_int
    use mesh_mod, only: mesh_t, mesh_create_indexed, mesh_destroy
    use spacecraft_materials_mod, only: spacecraft_material_t, &
                                        spacecraft_material_load, &
                                        spacecraft_material_destroy
    use logging, only: log_msg, LOG_INFO, LOG_WARN, LOG_ERROR
    implicit none
    private

    public :: spacecraft_submesh_t
    public :: spacecraft_model_t
    public :: spacecraft_model_load_obj, spacecraft_model_destroy

    integer, parameter :: FLOATS_PER_VERT = 14
    integer, parameter :: MAX_FACE_VERTS = 32
    integer, parameter :: MAX_MATERIAL_GROUPS = 256

    type, public :: spacecraft_submesh_t
        type(mesh_t) :: mesh
        type(spacecraft_material_t) :: material
        character(len=256) :: material_name = ""
    end type spacecraft_submesh_t

    type, public :: spacecraft_model_t
        type(spacecraft_submesh_t), allocatable :: submeshes(:)
        character(len=256) :: source_path = ""
        logical :: loaded = .false.
    end type spacecraft_model_t

contains

    subroutine spacecraft_model_load_obj(model, obj_path)
        type(spacecraft_model_t), intent(out) :: model
        character(len=*), intent(in) :: obj_path

        real(c_float), allocatable, target :: positions(:), texcoords(:), normals(:)
        real(c_float), allocatable, target :: vertices(:, :)
        integer(c_int), allocatable, target :: indices(:, :)
        integer :: unit, ios
        integer :: pos_count, tex_count, norm_count
        integer :: pos_cursor, tex_cursor, norm_cursor
        character(len=512) :: line, keyword, rest
        character(len=256) :: obj_dir, mtl_name, current_object
        character(len=256) :: material_names(MAX_MATERIAL_GROUPS)
        integer :: tri_counts(MAX_MATERIAL_GROUPS)
        integer :: vert_cursors(MAX_MATERIAL_GROUPS), idx_cursors(MAX_MATERIAL_GROUPS)
        integer :: material_count, material_idx, i, max_tri_count, submesh_count
        logical :: skip_object

        model%source_path = trim(obj_path)
        if (allocated(model%submeshes)) deallocate(model%submeshes)
        mtl_name = ""
        current_object = ""
        skip_object = .false.
        material_names = ""
        tri_counts = 0
        vert_cursors = 1
        idx_cursors = 1
        material_count = 1
        material_idx = 1
        material_names(1) = "__default__"
        pos_count = 0
        tex_count = 0
        norm_count = 0

        open(newunit=unit, file=trim(obj_path), status="old", action="read", &
             form="formatted", iostat=ios)
        if (ios /= 0) then
            call log_msg(LOG_ERROR, "Spacecraft OBJ load failed: " // trim(obj_path))
            return
        end if

        obj_dir = dirname(trim(obj_path))

        do
            read(unit, "(A)", iostat=ios) line
            if (ios /= 0) exit
            call strip_comment(line)
            if (len_trim(line) == 0) cycle
            call split_keyword(line, keyword, rest)

            select case (trim(keyword))
            case ("v")
                pos_count = pos_count + 1
            case ("vt")
                tex_count = tex_count + 1
            case ("vn")
                norm_count = norm_count + 1
            case ("o", "g")
                current_object = trim(rest)
                skip_object = is_helper_object(current_object)
            case ("usemtl")
                material_idx = find_or_add_material(trim(rest), material_names, material_count)
            case ("f")
                if (.not. skip_object) tri_counts(material_idx) = tri_counts(material_idx) + &
                                                                  face_triangle_count(rest)
            end select
        end do
        close(unit)

        allocate(positions(max(0, pos_count * 3)))
        allocate(texcoords(max(0, tex_count * 2)))
        allocate(normals(max(0, norm_count * 3)))
        if (size(positions) > 0) positions = 0.0_c_float
        if (size(texcoords) > 0) texcoords = 0.0_c_float
        if (size(normals) > 0) normals = 0.0_c_float
        pos_cursor = 1
        tex_cursor = 1
        norm_cursor = 1
        current_object = ""
        skip_object = .false.
        material_idx = 1

        max_tri_count = max(1, maxval(tri_counts(1:material_count)))
        allocate(vertices(max_tri_count * 3 * FLOATS_PER_VERT, material_count))
        allocate(indices(max_tri_count * 3, material_count))
        vertices = 0.0_c_float
        indices = 0_c_int

        open(newunit=unit, file=trim(obj_path), status="old", action="read", &
             form="formatted", iostat=ios)
        if (ios /= 0) then
            call log_msg(LOG_ERROR, "Spacecraft OBJ reload failed: " // trim(obj_path))
            return
        end if

        do
            read(unit, "(A)", iostat=ios) line
            if (ios /= 0) exit
            call strip_comment(line)
            if (len_trim(line) == 0) cycle
            call split_keyword(line, keyword, rest)

            select case (trim(keyword))
            case ("v")
                call store_real_triplet(positions, pos_cursor, rest)
            case ("vt")
                call store_real_pair(texcoords, tex_cursor, rest)
            case ("vn")
                call store_real_triplet(normals, norm_cursor, rest)
            case ("o", "g")
                current_object = trim(rest)
                skip_object = is_helper_object(current_object)
            case ("mtllib")
                if (len_trim(mtl_name) == 0) mtl_name = trim(rest)
            case ("usemtl")
                material_idx = find_or_add_material(trim(rest), material_names, material_count)
            case ("f")
                if (.not. skip_object) then
                    call write_face_vertices(rest, positions, texcoords, normals, &
                                             vertices(:, material_idx), indices(:, material_idx), &
                                             vert_cursors(material_idx), idx_cursors(material_idx))
                end if
            end select
        end do
        close(unit)

        submesh_count = count(tri_counts(1:material_count) > 0)
        if (submesh_count == 0) then
            call log_msg(LOG_WARN, "Spacecraft OBJ has no faces: " // trim(obj_path))
            return
        end if

        call normalize_loaded_submeshes(vertices, vert_cursors, material_count)

        allocate(model%submeshes(submesh_count))
        submesh_count = 0
        do i = 1, material_count
            if (tri_counts(i) <= 0) cycle
            submesh_count = submesh_count + 1
            model%submeshes(submesh_count)%material_name = trim(material_names(i))

            call mesh_create_indexed(model%submeshes(submesh_count)%mesh, &
                                     vertices(1:vert_cursors(i) - 1, i), &
                                     indices(1:idx_cursors(i) - 1, i))
            if (len_trim(mtl_name) > 0) then
                call load_material_from_mtl(model%submeshes(submesh_count)%material, &
                                            join_path(obj_dir, trim(mtl_name)), &
                                            material_names(i))
            end if
            call spacecraft_material_load(model%submeshes(submesh_count)%material)
        end do

        model%loaded = allocated(model%submeshes) .and. size(model%submeshes) > 0
        call log_msg(LOG_INFO, "Spacecraft OBJ loaded: " // trim(obj_path))
    end subroutine spacecraft_model_load_obj

    subroutine spacecraft_model_destroy(model)
        type(spacecraft_model_t), intent(inout) :: model
        integer :: i

        if (allocated(model%submeshes)) then
            do i = 1, size(model%submeshes)
                call mesh_destroy(model%submeshes(i)%mesh)
                call spacecraft_material_destroy(model%submeshes(i)%material)
            end do
            deallocate(model%submeshes)
        end if
        model%loaded = .false.
        model%source_path = ""
    end subroutine spacecraft_model_destroy

    subroutine write_face_vertices(rest, positions, texcoords, normals, vertices, indices, &
                                   vert_cursor, idx_cursor)
        character(len=*), intent(in) :: rest
        real(c_float), intent(in) :: positions(:), texcoords(:), normals(:)
        real(c_float), intent(inout), target :: vertices(:)
        integer(c_int), intent(inout), target :: indices(:)
        integer, intent(inout) :: vert_cursor, idx_cursor

        character(len=128) :: tokens(MAX_FACE_VERTS)
        integer :: count, i

        call tokenize(rest, tokens, count)
        if (count < 3) return

        do i = 2, count - 1
            call write_face_triangle(tokens(1), tokens(i), tokens(i + 1), &
                                     positions, texcoords, normals, vertices, indices, &
                                     vert_cursor, idx_cursor)
        end do
    end subroutine write_face_vertices

    subroutine write_face_triangle(t1, t2, t3, positions, texcoords, normals, vertices, indices, &
                                   vert_cursor, idx_cursor)
        character(len=*), intent(in) :: t1, t2, t3
        real(c_float), intent(in) :: positions(:), texcoords(:), normals(:)
        real(c_float), intent(inout), target :: vertices(:)
        integer(c_int), intent(inout), target :: indices(:)
        integer, intent(inout) :: vert_cursor, idx_cursor

        real(c_float) :: p1(3), p2(3), p3(3)
        real(c_float) :: uv1(2), uv2(2), uv3(2)
        real(c_float) :: n1(3), n2(3), n3(3)
        real(c_float) :: tangent(3), bitangent(3), face_normal(3)
        integer :: v_idx(3), vt_idx(3), vn_idx(3)
        integer(c_int) :: base_idx

        call parse_face_token(t1, v_idx(1), vt_idx(1), vn_idx(1))
        call parse_face_token(t2, v_idx(2), vt_idx(2), vn_idx(2))
        call parse_face_token(t3, v_idx(3), vt_idx(3), vn_idx(3))

        p1 = get_vec3(positions, v_idx(1))
        p2 = get_vec3(positions, v_idx(2))
        p3 = get_vec3(positions, v_idx(3))
        uv1 = get_vec2(texcoords, vt_idx(1))
        uv2 = get_vec2(texcoords, vt_idx(2))
        uv3 = get_vec2(texcoords, vt_idx(3))
        n1 = get_vec3(normals, vn_idx(1))
        n2 = get_vec3(normals, vn_idx(2))
        n3 = get_vec3(normals, vn_idx(3))

        face_normal = triangle_normal(p1, p2, p3)
        if (vn_idx(1) <= 0) n1 = face_normal
        if (vn_idx(2) <= 0) n2 = face_normal
        if (vn_idx(3) <= 0) n3 = face_normal

        call triangle_tangent_space(p1, p2, p3, uv1, uv2, uv3, tangent, bitangent)

        base_idx = int((vert_cursor - 1) / FLOATS_PER_VERT, c_int)
        call store_vertex(vertices, vert_cursor, p1, uv1, n1, tangent, bitangent)
        call store_vertex(vertices, vert_cursor, p2, uv2, n2, tangent, bitangent)
        call store_vertex(vertices, vert_cursor, p3, uv3, n3, tangent, bitangent)
        call store_int(indices, idx_cursor, base_idx)
        call store_int(indices, idx_cursor, base_idx + 1_c_int)
        call store_int(indices, idx_cursor, base_idx + 2_c_int)
    end subroutine write_face_triangle

    subroutine load_material_from_mtl(mat, mtl_path, wanted_name)
        type(spacecraft_material_t), intent(inout) :: mat
        character(len=*), intent(in) :: mtl_path
        character(len=*), intent(in) :: wanted_name

        integer :: unit, ios
        character(len=512) :: line, keyword, rest
        character(len=256) :: mtl_dir, current_name
        logical :: capture

        open(newunit=unit, file=trim(mtl_path), status="old", action="read", &
             form="formatted", iostat=ios)
        if (ios /= 0) then
            call log_msg(LOG_WARN, "Spacecraft MTL missing: " // trim(mtl_path))
            return
        end if

        mtl_dir = dirname(trim(mtl_path))
        current_name = ""
        capture = (len_trim(wanted_name) == 0)

        do
            read(unit, "(A)", iostat=ios) line
            if (ios /= 0) exit
            call strip_comment(line)
            if (len_trim(line) == 0) cycle
            call split_keyword(line, keyword, rest)

            select case (trim(keyword))
            case ("newmtl")
                current_name = trim(rest)
                capture = (len_trim(wanted_name) == 0 .or. trim(current_name) == trim(wanted_name))
                if (capture) mat%name = trim(current_name)
            case ("map_Kd")
                if (capture) mat%diffuse_path = join_path(mtl_dir, trim(rest))
            case ("map_Bump", "bump", "norm")
                if (capture) mat%normal_path = join_path(mtl_dir, trim(rest))
            end select
        end do
        close(unit)
    end subroutine load_material_from_mtl

    subroutine store_vertex(vertices, cursor, pos, uv, normal, tangent, bitangent)
        real(c_float), intent(inout), target :: vertices(:)
        integer, intent(inout) :: cursor
        real(c_float), intent(in) :: pos(3), uv(2), normal(3), tangent(3), bitangent(3)
        real(c_float) :: data(FLOATS_PER_VERT)

        data(1:3) = pos
        data(4:5) = uv
        data(6:8) = normal
        data(9:11) = tangent
        data(12:14) = bitangent
        if (cursor + FLOATS_PER_VERT - 1 > size(vertices)) return
        vertices(cursor:cursor + FLOATS_PER_VERT - 1) = data
        cursor = cursor + FLOATS_PER_VERT
    end subroutine store_vertex

    subroutine store_real_triplet(arr, cursor, text)
        real(c_float), intent(inout) :: arr(:)
        integer, intent(inout) :: cursor
        character(len=*), intent(in) :: text
        real(c_float) :: vals(3)
        integer :: ios

        read(text, *, iostat=ios) vals(1), vals(2), vals(3)
        if (ios /= 0) return
        if (cursor + 2 > size(arr)) return
        arr(cursor:cursor + 2) = vals
        cursor = cursor + 3
    end subroutine store_real_triplet

    subroutine store_real_pair(arr, cursor, text)
        real(c_float), intent(inout) :: arr(:)
        integer, intent(inout) :: cursor
        character(len=*), intent(in) :: text
        real(c_float) :: vals(2)
        integer :: ios

        vals = 0.0_c_float
        read(text, *, iostat=ios) vals(1), vals(2)
        if (ios /= 0) return
        if (cursor + 1 > size(arr)) return
        arr(cursor:cursor + 1) = vals
        cursor = cursor + 2
    end subroutine store_real_pair

    subroutine store_int(arr, cursor, val)
        integer(c_int), intent(inout) :: arr(:)
        integer, intent(inout) :: cursor
        integer(c_int), intent(in) :: val

        if (cursor > size(arr)) return
        arr(cursor) = val
        cursor = cursor + 1
    end subroutine store_int

    integer function face_triangle_count(rest) result(n_tri)
        character(len=*), intent(in) :: rest
        character(len=128) :: tokens(MAX_FACE_VERTS)
        integer :: count

        call tokenize(rest, tokens, count)
        n_tri = max(0, count - 2)
    end function face_triangle_count

    subroutine normalize_loaded_submeshes(vertices, vert_cursors, material_count)
        real(c_float), intent(inout), target :: vertices(:, :)
        integer, intent(in) :: vert_cursors(:)
        integer, intent(in) :: material_count
        integer :: i, j, n
        real(c_float) :: min_p(3), max_p(3), center(3), extent(3), max_extent

        min_p = huge(1.0_c_float)
        max_p = -huge(1.0_c_float)

        do j = 1, material_count
            if (vert_cursors(j) <= 1) cycle
            n = (vert_cursors(j) - 1) / FLOATS_PER_VERT
            do i = 0, n - 1
                min_p(1) = min(min_p(1), vertices(i * FLOATS_PER_VERT + 1, j))
                min_p(2) = min(min_p(2), vertices(i * FLOATS_PER_VERT + 2, j))
                min_p(3) = min(min_p(3), vertices(i * FLOATS_PER_VERT + 3, j))
                max_p(1) = max(max_p(1), vertices(i * FLOATS_PER_VERT + 1, j))
                max_p(2) = max(max_p(2), vertices(i * FLOATS_PER_VERT + 2, j))
                max_p(3) = max(max_p(3), vertices(i * FLOATS_PER_VERT + 3, j))
            end do
        end do

        center = 0.5_c_float * (min_p + max_p)
        extent = max_p - min_p
        max_extent = max(extent(1), max(extent(2), extent(3)))
        if (max_extent <= 1.0e-8_c_float) return

        do j = 1, material_count
            if (vert_cursors(j) <= 1) cycle
            n = (vert_cursors(j) - 1) / FLOATS_PER_VERT
            do i = 0, n - 1
                vertices(i * FLOATS_PER_VERT + 1, j) = &
                    (vertices(i * FLOATS_PER_VERT + 1, j) - center(1)) / max_extent
                vertices(i * FLOATS_PER_VERT + 2, j) = &
                    (vertices(i * FLOATS_PER_VERT + 2, j) - center(2)) / max_extent
                vertices(i * FLOATS_PER_VERT + 3, j) = &
                    (vertices(i * FLOATS_PER_VERT + 3, j) - center(3)) / max_extent
            end do
        end do
    end subroutine normalize_loaded_submeshes

    subroutine parse_face_token(token, v_idx, vt_idx, vn_idx)
        character(len=*), intent(in) :: token
        integer, intent(out) :: v_idx, vt_idx, vn_idx
        integer :: p1, p2, ios
        character(len=32) :: a, b, c

        v_idx = 0; vt_idx = 0; vn_idx = 0
        p1 = index(token, "/")
        if (p1 == 0) then
            read(token, *, iostat=ios) v_idx
            return
        end if

        p2 = index(token(p1 + 1:), "/")
        a = ""; b = ""; c = ""
        a = token(1:p1 - 1)
        if (p2 == 0) then
            b = token(p1 + 1:)
        else
            b = token(p1 + 1:p1 + p2 - 1)
            c = token(p1 + p2 + 1:)
        end if

        if (len_trim(a) > 0) read(a, *, iostat=ios) v_idx
        if (len_trim(b) > 0) read(b, *, iostat=ios) vt_idx
        if (len_trim(c) > 0) read(c, *, iostat=ios) vn_idx
    end subroutine parse_face_token

    subroutine tokenize(text, tokens, count)
        character(len=*), intent(in) :: text
        character(len=*), intent(out) :: tokens(:)
        integer, intent(out) :: count
        integer :: i, start, finish, n

        count = 0
        do i = 1, size(tokens)
            tokens(i) = ""
        end do

        n = len_trim(text)
        i = 1
        do while (i <= n)
            do while (i <= n .and. text(i:i) == " ")
                i = i + 1
            end do
            if (i > n) exit
            start = i
            do while (i <= n .and. text(i:i) /= " ")
                i = i + 1
            end do
            finish = i - 1
            count = count + 1
            if (count > size(tokens)) exit
            tokens(count) = text(start:finish)
        end do
        if (count > size(tokens)) count = size(tokens)
    end subroutine tokenize

    subroutine split_keyword(line, keyword, rest)
        character(len=*), intent(in) :: line
        character(len=*), intent(out) :: keyword, rest
        integer :: pos, n

        keyword = ""
        rest = ""
        n = len_trim(line)
        pos = index(line(1:n), " ")
        if (pos == 0) then
            keyword = trim(line(1:n))
        else
            keyword = trim(line(1:pos - 1))
            rest = adjustl(line(pos + 1:n))
        end if
    end subroutine split_keyword

    subroutine strip_comment(line)
        character(len=*), intent(inout) :: line
        integer :: pos
        pos = index(line, "#")
        if (pos > 0) line(pos:) = ""
        line = adjustl(trim(line))
    end subroutine strip_comment

    function get_vec3(arr, idx) result(v)
        real(c_float), intent(in) :: arr(:)
        integer, intent(in) :: idx
        real(c_float) :: v(3)
        integer :: base

        v = 0.0_c_float
        if (idx <= 0) return
        base = (idx - 1) * 3
        if (base + 3 > size(arr)) return
        v = arr(base + 1:base + 3)
    end function get_vec3

    function get_vec2(arr, idx) result(v)
        real(c_float), intent(in) :: arr(:)
        integer, intent(in) :: idx
        real(c_float) :: v(2)
        integer :: base

        v = 0.0_c_float
        if (idx <= 0) return
        base = (idx - 1) * 2
        if (base + 2 > size(arr)) return
        v = arr(base + 1:base + 2)
    end function get_vec2

    function triangle_normal(p1, p2, p3) result(n)
        real(c_float), intent(in) :: p1(3), p2(3), p3(3)
        real(c_float) :: n(3), e1(3), e2(3), len_n

        e1 = p2 - p1
        e2 = p3 - p1
        n(1) = e1(2) * e2(3) - e1(3) * e2(2)
        n(2) = e1(3) * e2(1) - e1(1) * e2(3)
        n(3) = e1(1) * e2(2) - e1(2) * e2(1)
        len_n = sqrt(max(dot_product(n, n), 1.0e-12_c_float))
        n = n / len_n
    end function triangle_normal

    subroutine triangle_tangent_space(p1, p2, p3, uv1, uv2, uv3, tangent, bitangent)
        real(c_float), intent(in) :: p1(3), p2(3), p3(3)
        real(c_float), intent(in) :: uv1(2), uv2(2), uv3(2)
        real(c_float), intent(out) :: tangent(3), bitangent(3)
        real(c_float) :: e1(3), e2(3), duv1(2), duv2(2), denom, inv_denom

        e1 = p2 - p1
        e2 = p3 - p1
        duv1 = uv2 - uv1
        duv2 = uv3 - uv1
        denom = duv1(1) * duv2(2) - duv2(1) * duv1(2)

        if (abs(denom) < 1.0e-8_c_float) then
            tangent = [1.0_c_float, 0.0_c_float, 0.0_c_float]
            bitangent = [0.0_c_float, 1.0_c_float, 0.0_c_float]
            return
        end if

        inv_denom = 1.0_c_float / denom
        tangent = inv_denom * (duv2(2) * e1 - duv1(2) * e2)
        bitangent = inv_denom * (-duv2(1) * e1 + duv1(1) * e2)
        call normalize_vec3(tangent)
        call normalize_vec3(bitangent)
    end subroutine triangle_tangent_space

    subroutine normalize_vec3(v)
        real(c_float), intent(inout) :: v(3)
        real(c_float) :: len_v

        len_v = sqrt(max(dot_product(v, v), 1.0e-12_c_float))
        v = v / len_v
    end subroutine normalize_vec3

    function dirname(path) result(dir)
        character(len=*), intent(in) :: path
        character(len=256) :: dir
        integer :: i

        dir = ""
        do i = len_trim(path), 1, -1
            if (path(i:i) == "/") then
                dir = path(1:i - 1)
                return
            end if
        end do
    end function dirname

    function join_path(dir, leaf) result(path)
        character(len=*), intent(in) :: dir, leaf
        character(len=256) :: path

        if (len_trim(leaf) == 0) then
            path = ""
        else if (leaf(1:1) == "/") then
            path = trim(leaf)
        else if (len_trim(dir) == 0) then
            path = trim(leaf)
        else
            path = trim(dir) // "/" // trim(leaf)
        end if
    end function join_path

    logical function is_helper_object(name) result(skip)
        character(len=*), intent(in) :: name
        skip = .false.
        if (len_trim(name) == 0) return
        if (name(1:1) == "_") skip = .true.
    end function is_helper_object

    integer function find_or_add_material(name, material_names, material_count) result(idx)
        character(len=*), intent(in) :: name
        character(len=256), intent(inout) :: material_names(:)
        integer, intent(inout) :: material_count
        integer :: i

        do i = 1, material_count
            if (trim(material_names(i)) == trim(name)) then
                idx = i
                return
            end if
        end do

        if (material_count >= size(material_names)) then
            idx = 1
            return
        end if

        material_count = material_count + 1
        material_names(material_count) = trim(name)
        idx = material_count
    end function find_or_add_material

end module spacecraft_assets_mod
