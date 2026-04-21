!===============================================================================
! menu.f90 — Top-bar menu with drop-down panels
!
! Pure Fortran, drawn through hud_text. The menu model is a flat list of
! drop-downs; each drop-down holds TOGGLE / SLIDER / BUTTON / SEPARATOR items
! identified by a small integer "field" or "action" enum. The menu owns no
! pointers into sim_config_t — instead main.f90 resolves each enum to the
! matching config field. This keeps menu.f90 reusable and avoids the TARGET
! attribute spreading into config_mod.
!
! Interaction model
!   - Click a title → toggle its drop-down (closes any other)
!   - Click a toggle/button row → dispatch, close drop-down
!   - Drag on a slider row → updates the 0..1 knob position
!   - Click outside any drop-down → close
!   - Menu "swallows" the mouse whenever the cursor is over the bar or an
!     open panel, so the orbit camera won't eat those events
!===============================================================================
module menu_mod
    use, intrinsic :: iso_c_binding, only: c_float, c_int, c_double
    use hud_text, only: hud_text_t, hud_text_rect, hud_text_draw, hud_text_width, &
                        GLYPH_H, GLYPH_ADVANCE
    implicit none
    private

    public :: menu_t, menu_item_t, menu_init, menu_shutdown
    public :: menu_update, menu_render, menu_mouse_captured
    public :: menu_pop_action, menu_add_dropdown, menu_add_submenu, menu_add_item
    public :: menu_set_toggle, menu_set_slider, menu_set_label
    public :: menu_get_toggle, menu_get_slider

    ! Item kinds
    integer, parameter, public :: ITEM_TOGGLE    = 1
    integer, parameter, public :: ITEM_BUTTON    = 2
    integer, parameter, public :: ITEM_SLIDER    = 3
    integer, parameter, public :: ITEM_SEPARATOR = 4
    integer, parameter, public :: ITEM_LABEL     = 5
    integer, parameter, public :: ITEM_SUBMENU   = 6

    ! Layout constants (pixels)
    real(c_float), parameter, public :: MENU_BAR_H   = 22.0_c_float
    real(c_float), parameter :: MENU_PAD_X    = 10.0_c_float
    real(c_float), parameter :: MENU_ITEM_H   = 20.0_c_float
    real(c_float), parameter :: MENU_PANEL_W  = 220.0_c_float
    real(c_float), parameter :: MENU_SEP_H    = 4.0_c_float
    real(c_float), parameter :: MENU_SLIDER_W = 80.0_c_float
    real(c_float), parameter :: MENU_SLIDER_H = 6.0_c_float

    ! Colors (0..1 linear; shader applies no gamma)
    real(c_float), parameter :: BAR_BG(3)      = [0.08_c_float, 0.09_c_float, 0.12_c_float]
    real(c_float), parameter :: BAR_HOVER(3)   = [0.20_c_float, 0.25_c_float, 0.35_c_float]
    real(c_float), parameter :: BAR_OPEN(3)    = [0.25_c_float, 0.40_c_float, 0.60_c_float]
    real(c_float), parameter :: PANEL_BG(3)    = [0.12_c_float, 0.14_c_float, 0.18_c_float]
    real(c_float), parameter :: PANEL_HOVER(3) = [0.22_c_float, 0.30_c_float, 0.45_c_float]
    real(c_float), parameter :: SEP_COLOR(3)   = [0.25_c_float, 0.28_c_float, 0.35_c_float]
    real(c_float), parameter :: TEXT_COLOR(3)  = [0.92_c_float, 0.94_c_float, 0.98_c_float]
    real(c_float), parameter :: TEXT_BACKDROP(3) = [0.05_c_float, 0.06_c_float, 0.08_c_float]
    real(c_float), parameter :: TEXT_BACKDROP_ACTIVE(3) = [0.08_c_float, 0.11_c_float, 0.16_c_float]
    real(c_float), parameter :: CHECK_ON(3)    = [0.55_c_float, 0.90_c_float, 0.55_c_float]
    real(c_float), parameter :: CHECK_OFF(3)   = [0.35_c_float, 0.35_c_float, 0.40_c_float]
    real(c_float), parameter :: SLIDER_TRACK(3)= [0.30_c_float, 0.32_c_float, 0.38_c_float]
    real(c_float), parameter :: SLIDER_FILL(3) = [0.55_c_float, 0.80_c_float, 1.00_c_float]

    type, public :: menu_item_t
        ! Default kind=0 marks an empty slot. count_items stops at the first
        ! kind=0 entry, so menu_add_item can find the next free slot after
        ! allocate(items(max_items)) default-initializes the array.
        integer                :: kind         = 0
        character(len=32)      :: label        = ""
        integer                :: field_id     = 0         ! for toggle/slider
        integer                :: action_id    = 0         ! for button
        integer                :: submenu_idx  = 0         ! for submenu rows
        real(c_float)          :: value        = 0.0_c_float
        logical                :: bool_value   = .false.
        real(c_float)          :: slider_min   = 0.0_c_float
        real(c_float)          :: slider_max   = 1.0_c_float
        logical                :: is_log       = .false.   ! sliders may be log10-scaled
    end type menu_item_t

    type, public :: menu_dropdown_t
        character(len=16) :: title = ""
        type(menu_item_t), allocatable :: items(:)
        real(c_float) :: title_x = 0.0_c_float   ! left edge of title in bar
        real(c_float) :: title_w = 0.0_c_float
        logical :: in_title_bar = .true.
    end type menu_dropdown_t

    type, public :: menu_t
        type(menu_dropdown_t), allocatable :: drop(:)
        integer :: n_drop = 0
        integer :: open_idx     = 0    ! 0 = none
        integer :: open_submenu_idx = 0
        integer :: hovered_drop = 0
        integer :: hovered_item = 0
        integer :: hovered_submenu_item = 0
        integer :: dragging_slider_drop = 0
        integer :: dragging_slider_item = 0
        integer :: pending_action       = 0   ! drained by main
        logical :: initialized          = .false.
    end type menu_t

contains

    subroutine menu_init(menu, max_dropdowns)
        type(menu_t), intent(out) :: menu
        integer, intent(in) :: max_dropdowns
        allocate(menu%drop(max_dropdowns))
        menu%n_drop = 0
        menu%open_idx = 0
        menu%open_submenu_idx = 0
        menu%hovered_drop = 0
        menu%hovered_item = 0
        menu%hovered_submenu_item = 0
        menu%dragging_slider_drop = 0
        menu%dragging_slider_item = 0
        menu%pending_action = 0
        menu%initialized = .true.
    end subroutine menu_init

    subroutine menu_shutdown(menu)
        type(menu_t), intent(inout) :: menu
        integer :: i
        if (.not. menu%initialized) return
        if (allocated(menu%drop)) then
            do i = 1, size(menu%drop)
                if (allocated(menu%drop(i)%items)) deallocate(menu%drop(i)%items)
            end do
            deallocate(menu%drop)
        end if
        menu%initialized = .false.
    end subroutine menu_shutdown

    !-------------------------------------------------------------------
    ! Build helpers — call during startup to populate the menu model.
    !-------------------------------------------------------------------
    subroutine menu_add_dropdown(menu, title, max_items, idx)
        type(menu_t), intent(inout) :: menu
        character(len=*), intent(in) :: title
        integer, intent(in) :: max_items
        integer, intent(out) :: idx
        if (menu%n_drop >= size(menu%drop)) then
            idx = 0
            return
        end if
        menu%n_drop = menu%n_drop + 1
        idx = menu%n_drop
        menu%drop(idx)%title = title
        menu%drop(idx)%in_title_bar = .true.
        allocate(menu%drop(idx)%items(max_items))
    end subroutine menu_add_dropdown

    subroutine menu_add_submenu(menu, parent_idx, label, max_items, submenu_idx)
        type(menu_t), intent(inout) :: menu
        integer, intent(in) :: parent_idx, max_items
        character(len=*), intent(in) :: label
        integer, intent(out) :: submenu_idx
        type(menu_item_t) :: it

        if (menu%n_drop >= size(menu%drop)) then
            submenu_idx = 0
            return
        end if
        menu%n_drop = menu%n_drop + 1
        submenu_idx = menu%n_drop
        menu%drop(submenu_idx)%title = ""
        menu%drop(submenu_idx)%in_title_bar = .false.
        allocate(menu%drop(submenu_idx)%items(max_items))

        it%kind = ITEM_SUBMENU
        it%label = label
        it%submenu_idx = submenu_idx
        call menu_add_item(menu, parent_idx, it)
    end subroutine menu_add_submenu

    subroutine menu_add_item(menu, drop_idx, it)
        type(menu_t), intent(inout) :: menu
        integer, intent(in) :: drop_idx
        type(menu_item_t), intent(in) :: it
        integer :: next_slot
        next_slot = count_items(menu%drop(drop_idx)) + 1
        if (next_slot > size(menu%drop(drop_idx)%items)) return
        menu%drop(drop_idx)%items(next_slot) = it
    end subroutine menu_add_item

    pure function count_items(dd) result(n)
        type(menu_dropdown_t), intent(in) :: dd
        integer :: i, n
        n = 0
        if (.not. allocated(dd%items)) return
        do i = 1, size(dd%items)
            if (dd%items(i)%kind == 0) return
            n = n + 1
        end do
    end function count_items

    !-------------------------------------------------------------------
    ! Update — consume mouse state; return actions via menu_pop_action.
    !
    ! mx, my       — cursor position (pixels; y grows downward)
    ! lmb_pressed  — mouse_just_pressed.left
    ! lmb_released — mouse_just_released.left
    ! lmb_held     — mouse%left
    ! values_io    — current toggle / slider values the menu should reflect;
    !                rewritten in place when the user changes them.
    !-------------------------------------------------------------------
    subroutine menu_update(menu, mx, my, lmb_pressed, lmb_released, lmb_held)
        type(menu_t), intent(inout) :: menu
        real(c_float), intent(in) :: mx, my
        logical, intent(in) :: lmb_pressed, lmb_released, lmb_held
        integer :: i, j, nitems
        real(c_float) :: title_x, panel_x, panel_y, row_y
        real(c_float) :: slider_x, t

        ! Recompute title positions each frame (labels might change length,
        ! though in practice they don't). Also updates hover state.
        call layout_titles(menu)

        menu%hovered_drop = 0
        menu%hovered_item = 0
        menu%hovered_submenu_item = 0

        ! --- Top bar hit test ---
        if (my >= 0.0_c_float .and. my < MENU_BAR_H) then
            do i = 1, menu%n_drop
                title_x = menu%drop(i)%title_x
                if (mx >= title_x .and. mx < title_x + menu%drop(i)%title_w) then
                    menu%hovered_drop = i
                    exit
                end if
            end do
            if (lmb_pressed) then
                if (menu%hovered_drop > 0) then
                    if (menu%open_idx == menu%hovered_drop) then
                        menu%open_idx = 0
                        menu%open_submenu_idx = 0
                    else
                        menu%open_idx = menu%hovered_drop
                        menu%open_submenu_idx = 0
                    end if
                else
                    menu%open_idx = 0
                    menu%open_submenu_idx = 0
                end if
                return
            end if
        end if

        ! --- Drop-down panel hit test (only if one is open) ---
        if (menu%open_idx > 0) then
            i = menu%open_idx
            panel_x = menu%drop(i)%title_x
            panel_y = MENU_BAR_H
            nitems = count_items(menu%drop(i))

            if (mx >= panel_x .and. mx < panel_x + MENU_PANEL_W .and. &
                my >= panel_y .and. &
                my < panel_y + panel_height(menu%drop(i))) then

                ! Find hovered row
                row_y = panel_y + 4.0_c_float
                do j = 1, nitems
                    if (menu%drop(i)%items(j)%kind == ITEM_SEPARATOR) then
                        row_y = row_y + MENU_SEP_H
                        cycle
                    end if
                    if (my >= row_y .and. my < row_y + MENU_ITEM_H) then
                        menu%hovered_item = j
                        menu%hovered_drop = i
                        exit
                    end if
                    row_y = row_y + MENU_ITEM_H
                end do

                if (lmb_pressed .and. menu%hovered_item > 0) then
                    associate (it => menu%drop(i)%items(menu%hovered_item))
                        select case (it%kind)
                        case (ITEM_TOGGLE)
                            it%bool_value = .not. it%bool_value
                            menu%pending_action = -it%field_id   ! negative = toggle field
                            menu%open_idx = 0
                        case (ITEM_BUTTON)
                            menu%pending_action = it%action_id
                            menu%open_idx = 0
                            menu%open_submenu_idx = 0
                        case (ITEM_SLIDER)
                            ! Compute slider_x and begin drag.
                            slider_x = panel_x + MENU_PANEL_W - MENU_SLIDER_W - 12.0_c_float
                            t = (mx - slider_x) / MENU_SLIDER_W
                            if (t < 0.0_c_float) t = 0.0_c_float
                            if (t > 1.0_c_float) t = 1.0_c_float
                            it%value = it%slider_min + t * (it%slider_max - it%slider_min)
                            menu%dragging_slider_drop = i
                            menu%dragging_slider_item = menu%hovered_item
                            menu%pending_action = it%field_id     ! positive = slider value
                        case (ITEM_SUBMENU)
                            if (menu%open_submenu_idx == it%submenu_idx) then
                                menu%open_submenu_idx = 0
                            else
                                menu%open_submenu_idx = it%submenu_idx
                            end if
                        end select
                    end associate
                end if
            else
                if (menu%open_submenu_idx > 0) then
                    call update_submenu_hover(menu, mx, my)
                end if
                if (menu%hovered_submenu_item > 0) then
                    if (lmb_pressed) then
                        associate (it => menu%drop(menu%open_submenu_idx)%items(menu%hovered_submenu_item))
                            select case (it%kind)
                            case (ITEM_BUTTON)
                                menu%pending_action = it%action_id
                                menu%open_idx = 0
                                menu%open_submenu_idx = 0
                            case (ITEM_TOGGLE)
                                it%bool_value = .not. it%bool_value
                                menu%pending_action = -it%field_id
                                menu%open_idx = 0
                                menu%open_submenu_idx = 0
                            end select
                        end associate
                    end if
                else
                    ! Click outside open panel → close
                    if (lmb_pressed) then
                        menu%open_idx = 0
                        menu%open_submenu_idx = 0
                    end if
                end if
            end if
        end if

        ! --- Ongoing slider drag ---
        if (menu%dragging_slider_drop > 0 .and. lmb_held) then
            i = menu%dragging_slider_drop
            j = menu%dragging_slider_item
            associate (it => menu%drop(i)%items(j))
                slider_x = menu%drop(i)%title_x + MENU_PANEL_W - MENU_SLIDER_W - 12.0_c_float
                t = (mx - slider_x) / MENU_SLIDER_W
                if (t < 0.0_c_float) t = 0.0_c_float
                if (t > 1.0_c_float) t = 1.0_c_float
                it%value = it%slider_min + t * (it%slider_max - it%slider_min)
                menu%pending_action = it%field_id
            end associate
        end if
        if (.not. lmb_held .or. lmb_released) then
            menu%dragging_slider_drop = 0
            menu%dragging_slider_item = 0
        end if
    end subroutine menu_update

    subroutine layout_titles(menu)
        type(menu_t), intent(inout) :: menu
        real(c_float) :: x
        integer :: i
        x = MENU_PAD_X
        do i = 1, menu%n_drop
            if (.not. menu%drop(i)%in_title_bar) cycle
            menu%drop(i)%title_x = x
            menu%drop(i)%title_w = hud_text_width(menu%drop(i)%title) + 2.0_c_float * MENU_PAD_X
            x = x + menu%drop(i)%title_w
        end do
    end subroutine layout_titles

    pure function panel_height(dd) result(h)
        type(menu_dropdown_t), intent(in) :: dd
        real(c_float) :: h
        integer :: i
        h = 8.0_c_float
        if (.not. allocated(dd%items)) return
        do i = 1, size(dd%items)
            if (dd%items(i)%kind == 0) exit
            if (dd%items(i)%kind == ITEM_SEPARATOR) then
                h = h + MENU_SEP_H
            else
                h = h + MENU_ITEM_H
            end if
        end do
    end function panel_height

    !-------------------------------------------------------------------
    ! Render — writes rects+glyphs into hud. Call between hud_text_clear
    ! and hud_text_render.
    !-------------------------------------------------------------------
    subroutine menu_render(menu, hud, screen_w)
        type(menu_t), intent(inout) :: menu
        type(hud_text_t), intent(inout) :: hud
        integer, intent(in) :: screen_w
        integer :: i, j, nitems
        real(c_float) :: panel_x, panel_y, row_y, ph
        real(c_float) :: sub_x, sub_y, sub_h
        real(c_float) :: sx, tnorm, fill_w
        real(c_float) :: label_w
        real(c_float) :: bg(3)
        character(len=48) :: vbuf
        logical :: highlight

        if (.not. menu%initialized .or. menu%n_drop == 0) return
        call layout_titles(menu)

        ! --- Top bar background ---
        call hud_text_rect(hud, 0.0_c_float, 0.0_c_float, &
                           real(screen_w, c_float), MENU_BAR_H, &
                           BAR_BG(1), BAR_BG(2), BAR_BG(3))

        ! --- Titles ---
        do i = 1, menu%n_drop
            if (.not. menu%drop(i)%in_title_bar) cycle
            bg = BAR_BG
            highlight = .false.
            if (i == menu%open_idx) then
                bg = BAR_OPEN
                highlight = .true.
            else if (i == menu%hovered_drop .and. menu%open_idx == 0) then
                bg = BAR_HOVER
                highlight = .true.
            end if
            if (highlight) then
                call hud_text_rect(hud, menu%drop(i)%title_x, 0.0_c_float, &
                                   menu%drop(i)%title_w, MENU_BAR_H, &
                                   bg(1), bg(2), bg(3))
            end if
            label_w = hud_text_width(trim(menu%drop(i)%title))
            call hud_text_rect(hud, &
                menu%drop(i)%title_x + MENU_PAD_X - 4.0_c_float, &
                0.5_c_float * (MENU_BAR_H - GLYPH_H) - 1.0_c_float, &
                label_w + 8.0_c_float, GLYPH_H + 2.0_c_float, &
                merge(TEXT_BACKDROP_ACTIVE(1), TEXT_BACKDROP(1), highlight), &
                merge(TEXT_BACKDROP_ACTIVE(2), TEXT_BACKDROP(2), highlight), &
                merge(TEXT_BACKDROP_ACTIVE(3), TEXT_BACKDROP(3), highlight))
            call hud_text_draw(hud, &
                menu%drop(i)%title_x + MENU_PAD_X, &
                0.5_c_float * (MENU_BAR_H - GLYPH_H), &
                trim(menu%drop(i)%title), &
                TEXT_COLOR(1), TEXT_COLOR(2), TEXT_COLOR(3))
        end do

        ! --- Open drop-down ---
        if (menu%open_idx > 0) then
            i = menu%open_idx
            panel_x = menu%drop(i)%title_x
            panel_y = MENU_BAR_H
            ph = panel_height(menu%drop(i))
            nitems = count_items(menu%drop(i))

            call hud_text_rect(hud, panel_x, panel_y, &
                               MENU_PANEL_W, ph, &
                               PANEL_BG(1), PANEL_BG(2), PANEL_BG(3))

            row_y = panel_y + 4.0_c_float
            do j = 1, nitems
                associate (it => menu%drop(i)%items(j))
                    select case (it%kind)
                    case (ITEM_SEPARATOR)
                        call hud_text_rect(hud, &
                            panel_x + 8.0_c_float, row_y + 0.5_c_float * MENU_SEP_H - 0.5_c_float, &
                            MENU_PANEL_W - 16.0_c_float, 1.0_c_float, &
                            SEP_COLOR(1), SEP_COLOR(2), SEP_COLOR(3))
                        row_y = row_y + MENU_SEP_H

                    case (ITEM_LABEL)
                        label_w = hud_text_width(trim(it%label))
                        call hud_text_rect(hud, &
                            panel_x + 10.0_c_float, &
                            row_y + 0.5_c_float * (MENU_ITEM_H - GLYPH_H) - 1.0_c_float, &
                            min(label_w + 8.0_c_float, MENU_PANEL_W - 20.0_c_float), &
                            GLYPH_H + 2.0_c_float, &
                            TEXT_BACKDROP(1), TEXT_BACKDROP(2), TEXT_BACKDROP(3))
                        call hud_text_draw(hud, &
                            panel_x + 12.0_c_float, &
                            row_y + 0.5_c_float * (MENU_ITEM_H - GLYPH_H), &
                            trim(it%label), &
                            TEXT_COLOR(1) * 0.7_c_float, &
                            TEXT_COLOR(2) * 0.7_c_float, &
                            TEXT_COLOR(3) * 0.7_c_float)
                        row_y = row_y + MENU_ITEM_H

                    case (ITEM_SUBMENU)
                        if (menu%hovered_drop == i .and. menu%hovered_item == j) then
                            call hud_text_rect(hud, panel_x + 2.0_c_float, row_y, &
                                               MENU_PANEL_W - 4.0_c_float, MENU_ITEM_H, &
                                               PANEL_HOVER(1), PANEL_HOVER(2), PANEL_HOVER(3))
                        end if
                        label_w = hud_text_width(trim(it%label))
                        call hud_text_rect(hud, &
                            panel_x + 24.0_c_float, &
                            row_y + 0.5_c_float * (MENU_ITEM_H - GLYPH_H) - 1.0_c_float, &
                            min(label_w + 20.0_c_float, MENU_PANEL_W - 40.0_c_float), &
                            GLYPH_H + 2.0_c_float, &
                            merge(TEXT_BACKDROP_ACTIVE(1), TEXT_BACKDROP(1), &
                                  menu%hovered_drop == i .and. menu%hovered_item == j), &
                            merge(TEXT_BACKDROP_ACTIVE(2), TEXT_BACKDROP(2), &
                                  menu%hovered_drop == i .and. menu%hovered_item == j), &
                            merge(TEXT_BACKDROP_ACTIVE(3), TEXT_BACKDROP(3), &
                                  menu%hovered_drop == i .and. menu%hovered_item == j))
                        call hud_text_draw(hud, panel_x + 28.0_c_float, &
                                           row_y + 0.5_c_float * (MENU_ITEM_H - GLYPH_H), &
                                           trim(it%label), TEXT_COLOR(1), TEXT_COLOR(2), TEXT_COLOR(3))
                        call hud_text_draw(hud, panel_x + MENU_PANEL_W - 18.0_c_float, &
                                           row_y + 0.5_c_float * (MENU_ITEM_H - GLYPH_H), &
                                           ">", TEXT_COLOR(1), TEXT_COLOR(2), TEXT_COLOR(3))
                        row_y = row_y + MENU_ITEM_H

                    case default
                        if (menu%hovered_drop == i .and. menu%hovered_item == j) then
                            call hud_text_rect(hud, panel_x + 2.0_c_float, row_y, &
                                               MENU_PANEL_W - 4.0_c_float, MENU_ITEM_H, &
                                               PANEL_HOVER(1), PANEL_HOVER(2), PANEL_HOVER(3))
                        end if

                        label_w = hud_text_width(trim(it%label))
                        call hud_text_rect(hud, &
                            panel_x + 24.0_c_float, &
                            row_y + 0.5_c_float * (MENU_ITEM_H - GLYPH_H) - 1.0_c_float, &
                            min(label_w + 8.0_c_float, MENU_PANEL_W - 110.0_c_float), &
                            GLYPH_H + 2.0_c_float, &
                            merge(TEXT_BACKDROP_ACTIVE(1), TEXT_BACKDROP(1), &
                                  menu%hovered_drop == i .and. menu%hovered_item == j), &
                            merge(TEXT_BACKDROP_ACTIVE(2), TEXT_BACKDROP(2), &
                                  menu%hovered_drop == i .and. menu%hovered_item == j), &
                            merge(TEXT_BACKDROP_ACTIVE(3), TEXT_BACKDROP(3), &
                                  menu%hovered_drop == i .and. menu%hovered_item == j))
                        call hud_text_draw(hud, &
                            panel_x + 28.0_c_float, &
                            row_y + 0.5_c_float * (MENU_ITEM_H - GLYPH_H), &
                            trim(it%label), &
                            TEXT_COLOR(1), TEXT_COLOR(2), TEXT_COLOR(3))

                        if (it%kind == ITEM_TOGGLE) then
                            ! Check box at left
                            call hud_text_rect(hud, &
                                panel_x + 10.0_c_float, &
                                row_y + 0.5_c_float * (MENU_ITEM_H - 10.0_c_float), &
                                10.0_c_float, 10.0_c_float, &
                                CHECK_OFF(1), CHECK_OFF(2), CHECK_OFF(3))
                            if (it%bool_value) then
                                call hud_text_rect(hud, &
                                    panel_x + 12.0_c_float, &
                                    row_y + 0.5_c_float * (MENU_ITEM_H - 10.0_c_float) + 2.0_c_float, &
                                    6.0_c_float, 6.0_c_float, &
                                    CHECK_ON(1), CHECK_ON(2), CHECK_ON(3))
                            end if

                        else if (it%kind == ITEM_SLIDER) then
                            sx = panel_x + MENU_PANEL_W - MENU_SLIDER_W - 12.0_c_float
                            call hud_text_rect(hud, sx, &
                                row_y + 0.5_c_float * (MENU_ITEM_H - MENU_SLIDER_H), &
                                MENU_SLIDER_W, MENU_SLIDER_H, &
                                SLIDER_TRACK(1), SLIDER_TRACK(2), SLIDER_TRACK(3))
                            if (it%slider_max > it%slider_min) then
                                tnorm = (it%value - it%slider_min) / (it%slider_max - it%slider_min)
                            else
                                tnorm = 0.0_c_float
                            end if
                            if (tnorm < 0.0_c_float) tnorm = 0.0_c_float
                            if (tnorm > 1.0_c_float) tnorm = 1.0_c_float
                            fill_w = tnorm * MENU_SLIDER_W
                            if (fill_w > 0.0_c_float) then
                                call hud_text_rect(hud, sx, &
                                    row_y + 0.5_c_float * (MENU_ITEM_H - MENU_SLIDER_H), &
                                    fill_w, MENU_SLIDER_H, &
                                    SLIDER_FILL(1), SLIDER_FILL(2), SLIDER_FILL(3))
                            end if

                            ! Numeric readout to the right of the track,
                            ! drawn above it (no room beside on narrow panels).
                            write(vbuf, "(F0.2)") it%value
                            label_w = hud_text_width(trim(vbuf))
                            call hud_text_rect(hud, &
                                sx + MENU_SLIDER_W - label_w - 4.0_c_float, &
                                row_y + 0.5_c_float * (MENU_ITEM_H - GLYPH_H) - 1.0_c_float, &
                                label_w + 8.0_c_float, GLYPH_H + 2.0_c_float, &
                                TEXT_BACKDROP(1), TEXT_BACKDROP(2), TEXT_BACKDROP(3))
                            call hud_text_draw(hud, &
                                sx + MENU_SLIDER_W - hud_text_width(trim(vbuf)), &
                                row_y + 0.5_c_float * (MENU_ITEM_H - GLYPH_H), &
                                trim(vbuf), &
                                TEXT_COLOR(1), TEXT_COLOR(2), TEXT_COLOR(3))
                        end if

                        row_y = row_y + MENU_ITEM_H
                    end select
                end associate
            end do

            if (menu%open_submenu_idx > 0) then
                call submenu_panel_rect(menu, menu%open_idx, menu%open_submenu_idx, sub_x, sub_y, sub_h)
                nitems = count_items(menu%drop(menu%open_submenu_idx))
                call hud_text_rect(hud, sub_x, sub_y, MENU_PANEL_W, sub_h, &
                                   PANEL_BG(1), PANEL_BG(2), PANEL_BG(3))
                row_y = sub_y + 4.0_c_float
                do j = 1, nitems
                    associate (it => menu%drop(menu%open_submenu_idx)%items(j))
                        if (it%kind == ITEM_SEPARATOR) then
                            call hud_text_rect(hud, sub_x + 8.0_c_float, &
                                row_y + 0.5_c_float * MENU_SEP_H - 0.5_c_float, &
                                MENU_PANEL_W - 16.0_c_float, 1.0_c_float, &
                                SEP_COLOR(1), SEP_COLOR(2), SEP_COLOR(3))
                            row_y = row_y + MENU_SEP_H
                            cycle
                        end if
                        if (menu%hovered_submenu_item == j) then
                            call hud_text_rect(hud, sub_x + 2.0_c_float, row_y, &
                                               MENU_PANEL_W - 4.0_c_float, MENU_ITEM_H, &
                                               PANEL_HOVER(1), PANEL_HOVER(2), PANEL_HOVER(3))
                        end if
                        label_w = hud_text_width(trim(it%label))
                        call hud_text_rect(hud, &
                            sub_x + 24.0_c_float, &
                            row_y + 0.5_c_float * (MENU_ITEM_H - GLYPH_H) - 1.0_c_float, &
                            min(label_w + 8.0_c_float, MENU_PANEL_W - 40.0_c_float), &
                            GLYPH_H + 2.0_c_float, &
                            merge(TEXT_BACKDROP_ACTIVE(1), TEXT_BACKDROP(1), menu%hovered_submenu_item == j), &
                            merge(TEXT_BACKDROP_ACTIVE(2), TEXT_BACKDROP(2), menu%hovered_submenu_item == j), &
                            merge(TEXT_BACKDROP_ACTIVE(3), TEXT_BACKDROP(3), menu%hovered_submenu_item == j))
                        call hud_text_draw(hud, sub_x + 28.0_c_float, &
                                           row_y + 0.5_c_float * (MENU_ITEM_H - GLYPH_H), &
                                           trim(it%label), TEXT_COLOR(1), TEXT_COLOR(2), TEXT_COLOR(3))
                        row_y = row_y + MENU_ITEM_H
                    end associate
                end do
            end if
        end if
    end subroutine menu_render

    !-------------------------------------------------------------------
    ! True iff the cursor is over the bar or the open panel. Main uses
    ! this to skip camera-handle-input and key handlers so the menu
    ! doesn't double-drive the scene.
    !-------------------------------------------------------------------
    function menu_mouse_captured(menu, mx, my) result(captured)
        type(menu_t), intent(in) :: menu
        real(c_float), intent(in) :: mx, my
        logical :: captured
        real(c_float) :: panel_x, panel_y, ph
        integer :: i
        real(c_float) :: sub_x, sub_y, sub_h
        captured = .false.
        if (.not. menu%initialized) return
        if (my >= 0.0_c_float .and. my < MENU_BAR_H) then
            captured = .true.
            return
        end if
        if (menu%dragging_slider_drop > 0) then
            captured = .true.
            return
        end if
        if (menu%open_idx > 0) then
            i = menu%open_idx
            panel_x = menu%drop(i)%title_x
            panel_y = MENU_BAR_H
            ph = panel_height(menu%drop(i))
            if (mx >= panel_x .and. mx < panel_x + MENU_PANEL_W .and. &
                my >= panel_y .and. my < panel_y + ph) then
                captured = .true.
                return
            end if
            if (menu%open_submenu_idx > 0) then
                call submenu_panel_rect(menu, menu%open_idx, menu%open_submenu_idx, sub_x, sub_y, sub_h)
                if (mx >= sub_x .and. mx < sub_x + MENU_PANEL_W .and. &
                    my >= sub_y .and. my < sub_y + sub_h) then
                    captured = .true.
                    return
                end if
            end if
        end if
    end function menu_mouse_captured

    subroutine submenu_panel_rect(menu, parent_idx, submenu_idx, x, y, h)
        type(menu_t), intent(in) :: menu
        integer, intent(in) :: parent_idx, submenu_idx
        real(c_float), intent(out) :: x, y, h
        integer :: j
        real(c_float) :: row_y

        x = menu%drop(parent_idx)%title_x + MENU_PANEL_W - 2.0_c_float
        y = MENU_BAR_H + 4.0_c_float
        h = panel_height(menu%drop(submenu_idx))
        row_y = MENU_BAR_H + 4.0_c_float
        do j = 1, count_items(menu%drop(parent_idx))
            if (menu%drop(parent_idx)%items(j)%kind == ITEM_SEPARATOR) then
                row_y = row_y + MENU_SEP_H
                cycle
            end if
            if (menu%drop(parent_idx)%items(j)%kind == ITEM_SUBMENU .and. &
                menu%drop(parent_idx)%items(j)%submenu_idx == submenu_idx) then
                y = row_y - 2.0_c_float
                return
            end if
            row_y = row_y + MENU_ITEM_H
        end do
    end subroutine submenu_panel_rect

    subroutine update_submenu_hover(menu, mx, my)
        type(menu_t), intent(inout) :: menu
        real(c_float), intent(in) :: mx, my
        integer :: j, nitems
        real(c_float) :: sub_x, sub_y, sub_h, row_y

        menu%hovered_submenu_item = 0
        if (menu%open_idx <= 0 .or. menu%open_submenu_idx <= 0) return
        call submenu_panel_rect(menu, menu%open_idx, menu%open_submenu_idx, sub_x, sub_y, sub_h)
        if (.not. (mx >= sub_x .and. mx < sub_x + MENU_PANEL_W .and. my >= sub_y .and. my < sub_y + sub_h)) return

        nitems = count_items(menu%drop(menu%open_submenu_idx))
        row_y = sub_y + 4.0_c_float
        do j = 1, nitems
            if (menu%drop(menu%open_submenu_idx)%items(j)%kind == ITEM_SEPARATOR) then
                row_y = row_y + MENU_SEP_H
                cycle
            end if
            if (my >= row_y .and. my < row_y + MENU_ITEM_H) then
                menu%hovered_submenu_item = j
                return
            end if
            row_y = row_y + MENU_ITEM_H
        end do
    end subroutine update_submenu_hover


    !-------------------------------------------------------------------
    ! Pop the pending action code (main.f90 should call this each frame
    ! and dispatch the enum to the appropriate cfg update).
    !
    ! Returns:
    !   0            — nothing happened
    !   positive id  — slider/button event (see field_id / action_id)
    !   negative id  — toggle event; magnitude is the field_id, and the
    !                  toggle's new state can be read from its bool_value
    !-------------------------------------------------------------------
    function menu_pop_action(menu) result(act)
        type(menu_t), intent(inout) :: menu
        integer :: act
        act = menu%pending_action
        menu%pending_action = 0
    end function menu_pop_action

    !-------------------------------------------------------------------
    ! field_id → item lookup helpers. Sliders use positive field ids and
    ! toggles use positive field ids internally; they never collide
    ! because item kind disambiguates them.
    !-------------------------------------------------------------------
    subroutine menu_set_toggle(menu, field_id, v)
        type(menu_t), intent(inout) :: menu
        integer, intent(in) :: field_id
        logical, intent(in) :: v
        integer :: i, j
        if (.not. menu%initialized) return
        do i = 1, menu%n_drop
            if (.not. allocated(menu%drop(i)%items)) cycle
            do j = 1, size(menu%drop(i)%items)
                if (menu%drop(i)%items(j)%kind == ITEM_TOGGLE .and. &
                    menu%drop(i)%items(j)%field_id == field_id) then
                    menu%drop(i)%items(j)%bool_value = v
                end if
            end do
        end do
    end subroutine menu_set_toggle

    subroutine menu_set_slider(menu, field_id, v)
        type(menu_t), intent(inout) :: menu
        integer, intent(in) :: field_id
        real(c_float), intent(in) :: v
        integer :: i, j
        if (.not. menu%initialized) return
        do i = 1, menu%n_drop
            if (.not. allocated(menu%drop(i)%items)) cycle
            do j = 1, size(menu%drop(i)%items)
                if (menu%drop(i)%items(j)%kind == ITEM_SLIDER .and. &
                    menu%drop(i)%items(j)%field_id == field_id) then
                    menu%drop(i)%items(j)%value = v
                end if
            end do
        end do
    end subroutine menu_set_slider

    subroutine menu_set_label(menu, field_id, text)
        type(menu_t), intent(inout) :: menu
        integer, intent(in) :: field_id
        character(len=*), intent(in) :: text
        integer :: i, j
        if (.not. menu%initialized) return
        do i = 1, menu%n_drop
            if (.not. allocated(menu%drop(i)%items)) cycle
            do j = 1, size(menu%drop(i)%items)
                if (menu%drop(i)%items(j)%kind == ITEM_LABEL .and. &
                    menu%drop(i)%items(j)%field_id == field_id) then
                    menu%drop(i)%items(j)%label = text
                end if
            end do
        end do
    end subroutine menu_set_label

    pure function menu_get_toggle(menu, field_id) result(v)
        type(menu_t), intent(in) :: menu
        integer, intent(in) :: field_id
        logical :: v
        integer :: i, j
        v = .false.
        if (.not. menu%initialized) return
        do i = 1, menu%n_drop
            if (.not. allocated(menu%drop(i)%items)) cycle
            do j = 1, size(menu%drop(i)%items)
                if (menu%drop(i)%items(j)%kind == ITEM_TOGGLE .and. &
                    menu%drop(i)%items(j)%field_id == field_id) then
                    v = menu%drop(i)%items(j)%bool_value
                    return
                end if
            end do
        end do
    end function menu_get_toggle

    pure function menu_get_slider(menu, field_id) result(v)
        type(menu_t), intent(in) :: menu
        integer, intent(in) :: field_id
        real(c_float) :: v
        integer :: i, j
        v = 0.0_c_float
        if (.not. menu%initialized) return
        do i = 1, menu%n_drop
            if (.not. allocated(menu%drop(i)%items)) cycle
            do j = 1, size(menu%drop(i)%items)
                if (menu%drop(i)%items(j)%kind == ITEM_SLIDER .and. &
                    menu%drop(i)%items(j)%field_id == field_id) then
                    v = menu%drop(i)%items(j)%value
                    return
                end if
            end do
        end do
    end function menu_get_slider

end module menu_mod
