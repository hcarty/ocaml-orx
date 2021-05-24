let ( !@ ) = Ctypes.( !@ )

let fail fmt = Fmt.kstr failwith ("Orx: " ^^ fmt)

let create_exn create_from_config what name =
  match create_from_config name with
  | Some o -> o
  | None -> Fmt.invalid_arg "Unable to create %s %s" what name

(* Protect OCaml values from GC collection so they can be safely passed to Orx.
   Code from
   https://discuss.ocaml.org/t/ctypes-whats-the-most-idiomatic-way-to-anchor-an-ocaml-value-so-that-its-not-garbage-collected/6258/2 *)
module Store : sig
  (* type ticket *)
  val retain_permanently : 'a -> unit

  (* val retain : 'a -> ticket *)
  (* val is_live : ticket -> bool *)
  (* val release : ticket -> unit *)
end = struct
  type ticket = int
  type element = E : _ -> element
  let counter = ref 0
  let store = Hashtbl.create 10
  let retain v =
    let ticket = !counter in
    incr counter;
    Hashtbl.add store ticket (E v);
    ticket
  let retain_permanently v =
    let (_ : ticket) = retain v in
    ()
  let _is_live = Hashtbl.mem store
  let _release = Hashtbl.remove store
end

module Orx_gen = Orx_bindings.Bindings (Generated)

type camera = Orx_gen.Camera.t
type obj = Orx_gen.Object.t

module Color = Orx_gen.Color
module Display = Orx_gen.Display
module Resource = Orx_gen.Resource
module Sound = Orx_gen.Sound
module String_id = Orx_gen.String_id
module Structure = Orx_gen.Structure
module Structure_id = Orx_types.Structure_id
module Status = Orx_gen.Status
module Clock_modifier = Orx_types.Clock_modifier
module Clock_priority = Orx_types.Clock_priority
module Clock_info = Orx_types.Clock_info
module Module_id = Orx_types.Module_id
module Shader_param_type = Orx_gen.Shader_param_type
module Config_event = Orx_types.Config_event
module Fx_event = Orx_gen.Fx_event
module Input_event = Orx_gen.Input_event
module Object_event = Orx_gen.Object_event
module Physics_event = Orx_gen.Physics_event
module Sound_event = Orx_gen.Sound_event
module Time_line_event = Orx_gen.Time_line_event
module Input_mode = Orx_types.Input_mode
module Input_type = Orx_types.Input_type
module Mouse_axis = Orx_types.Mouse_axis
module Mouse_button = Orx_types.Mouse_button
module Sound_status = Orx_types.Sound_status
module Shader_pointer = Orx_gen.Shader_pointer
module Time_line = Orx_gen.Time_line

module Log = struct
  type 'a format_logger =
    ('a, Format.formatter, unit, unit, unit, unit) format6 -> 'a

  let log fmt = Fmt.kstr Orx_gen.Log.log fmt
  let terminal fmt = Fmt.kstr Orx_gen.Log.terminal fmt
  let file fmt = Fmt.kstr Orx_gen.Log.file fmt
  let console fmt = Fmt.kstr Orx_gen.Log.console fmt
end

module Texture = struct
  include Orx_gen.Texture

  let get_size texture =
    let width = Ctypes.allocate_n Ctypes.float ~count:1 in
    let height = Ctypes.allocate_n Ctypes.float ~count:1 in
    match get_size texture width height with
    | Error `Orx -> None
    | Ok () -> Some (!@width, !@height)
end

module Bank = struct
  include Orx_gen.Bank

  let rec to_list
      (b : t)
      (cell : unit Ctypes.ptr option)
      (ptrs : unit Ctypes.ptr list) =
    match get_next b cell with
    | None -> List.rev ptrs
    | Some ptr as next_cell -> to_list b next_cell (ptr :: ptrs)

  let to_list (b : t) : unit Ctypes.ptr list = to_list b None []
end

module Vector = struct
  include Orx_gen.Vector

  let get_x (v : t) : float = Ctypes.getf !@v Orx_types.Vector.x

  let get_y (v : t) : float = Ctypes.getf !@v Orx_types.Vector.y

  let get_z (v : t) : float = Ctypes.getf !@v Orx_types.Vector.z

  let equal_2d (a : t) (b : t) : bool =
    Float.equal (get_x a) (get_x b) && Float.equal (get_y a) (get_y b)

  let pp ppf (v : t) = Fmt.pf ppf "(%g, %g, %g)" (get_x v) (get_y v) (get_z v)

  let make ~x ~y ~z : t =
    let v = allocate_raw () in
    let (_ : t) = set v x y z in
    v

  let set_x (v : t) (x : float) : unit = Ctypes.setf !@v Orx_types.Vector.x x

  let set_y (v : t) (y : float) : unit = Ctypes.setf !@v Orx_types.Vector.y y

  let set_z (v : t) (z : float) : unit = Ctypes.setf !@v Orx_types.Vector.z z

  let make_one_vec_op op =
    let f' ~(target : t) (v : t) : unit =
      let (_ : t) = op target v in
      ()
    in
    let f (v : t) : t =
      let target : t = allocate_raw () in
      f' ~target v;
      target
    in
    (f', f)

  let (copy', copy) = make_one_vec_op copy

  let (normalize', normalize) = make_one_vec_op normalize

  let (reciprocal', reciprocal) = make_one_vec_op reciprocal

  let (round', round) = make_one_vec_op round

  let (floor', floor) = make_one_vec_op floor

  let (neg', neg) = make_one_vec_op neg

  let make_two_vec_op op =
    let f' ~(target : t) (v1 : t) (v2 : t) : unit =
      let (_ : t) = op target v1 v2 in
      ()
    in
    let f (v1 : t) (v2 : t) : t =
      let target : t = allocate_raw () in
      f' ~target v1 v2;
      target
    in
    (f', f)

  let (add', add) = make_two_vec_op add

  let (sub', sub) = make_two_vec_op sub

  let (mul', mul) = make_two_vec_op mul

  let (div', div) = make_two_vec_op div

  let (cross', cross) = make_two_vec_op cross

  let make_one_vec_one_float_op op =
    let f' ~(target : t) (v : t) (x : float) : unit =
      let (_ : t) = op target v x in
      ()
    in

    let f (v : t) (x : float) : t =
      let target : t = allocate_raw () in
      f' ~target v x;
      target
    in
    (f', f)

  let (mulf', mulf) = make_one_vec_one_float_op mulf

  let (divf', divf) = make_one_vec_one_float_op divf

  let (rotate_2d', rotate_2d) = make_one_vec_one_float_op rotate_2d

  let make_two_vec_one_float_op op =
    let f' ~(target : t) (v1 : t) (v2 : t) (x : float) : unit =
      let (_ : t) = op target v1 v2 x in
      ()
    in

    let f (v1 : t) (v2 : t) (x : float) : t =
      let target : t = allocate_raw () in
      f' ~target v1 v2 x;
      target
    in
    (f', f)

  let (lerp', lerp) = make_two_vec_one_float_op lerp

  let move_x (v : t) (delta : float) : unit = set_x v (get_x v +. delta)

  let move_y (v : t) (delta : float) : unit = set_y v (get_y v +. delta)

  let move_z (v : t) (delta : float) : unit = set_z v (get_z v +. delta)

  let of_rotation (rotation : float) : t =
    let x = cos rotation in
    let y = sin rotation in
    make ~x ~y ~z:0.0

  let to_rotation (v : t) : float = Float.atan2 (get_y v) (get_x v)
end

module Obox = struct
  include Orx_gen.Obox

  let make ~pos ~pivot ~size angle : t =
    let ob = allocate_raw () in
    let (_ : t) = set_2d ob pos pivot size angle in
    ob

  let copy (ob : t) =
    let copied : t = allocate_raw () in
    let (_ : t) = copy copied ob in
    copied

  let get_center (ob : t) : Vector.t =
    let center = Vector.allocate_raw () in
    let (_ : Vector.t) = get_center ob center in
    center

  let move (ob : t) (v : Vector.t) : t =
    let moved : t = allocate_raw () in
    let (_ : t) = move moved ob v in
    moved

  let rotate_2d (ob : t) angle : t =
    let rotated : t = allocate_raw () in
    let (_ : t) = rotate_2d rotated ob angle in
    rotated
end

module Shader = struct
  include Orx_gen.Shader

  let set_float_param_exn shader name value =
    let argument = Ctypes.(allocate float value) in
    match set_float_param shader name 0 argument with
    | Error `Orx ->
      Fmt.invalid_arg "Unable to set parameter %s to %g in shader %s" name value
        (get_name shader)
    | Ok () -> ()

  let set_vector_param_exn shader name value =
    match set_vector_param shader name 0 value with
    | Error `Orx ->
      Fmt.invalid_arg "Unable to set parameter %s to %a in shader %s" name
        Vector.pp value (get_name shader)
    | Ok () -> ()
end

module Shader_event = struct
  include Orx_gen.Shader_event

  let set_param_float payload v =
    if get_param_type payload <> Float then
      Fmt.invalid_arg "Shader param %s is not of type float"
        (get_param_name payload);
    set_param_float payload v

  let set_param_vector payload v =
    if get_param_type payload <> Vector then
      Fmt.invalid_arg "Shader param %s is not of type vector"
        (get_param_name payload);
    set_param_vector payload v
end

module Viewport = struct
  include Orx_gen.Viewport

  let create_from_config_exn = create_exn create_from_config "viewport"

  let get_shader_exn ?(index = 0) v =
    match get_shader_pointer v with
    | None ->
      Fmt.invalid_arg "No shader pointer associated with viewport %s"
        (get_name v)
    | Some pointer ->
      ( match Orx_gen.Shader_pointer.get_shader pointer index with
      | None ->
        Fmt.invalid_arg "No shader %d associated with viewport %s" index
          (get_name v)
      | Some shader -> shader
      )

  let get_exn name =
    match get name with
    | None -> Fmt.invalid_arg "No viewport %s available" name
    | Some viewport -> viewport
end

(* Wrapper for functions which return a vector property. *)
(* Orx uses the return value to indicate if the get was a success or not. *)
let get_optional_vector get o =
  let v = Vector.allocate_raw () in
  match get o v with
  | None -> None
  | Some _v -> Some v

let get_vector_exn get o =
  match get_optional_vector get o with
  | None -> fail "Failed to set vector"
  | Some v -> v

let get_vector get o =
  let v = Vector.allocate_raw () in
  let (_ : Vector.t) = get o v in
  v

(* Wrapper for functions which return a obox property. *)
(* Orx uses the return value to indicate if the get was a success or not. *)
let get_obox_exn get o =
  let v = Obox.allocate_raw () in
  match get o v with
  | None -> fail "Failed to allocate obox"
  | Some _v -> v

module Render = struct
  include Orx_gen.Render

  let get_world_position vector viewport =
    get_optional_vector (fun () v -> get_world_position vector viewport v) ()

  let get_screen_position vector viewport =
    get_optional_vector (fun () v -> get_screen_position vector viewport v) ()
end

module Mouse = struct
  include Orx_gen.Mouse

  let get_position = get_optional_vector (fun () v -> get_position v)

  let get_move_delta = get_optional_vector (fun () v -> get_move_delta v)
end

module Graphic = struct
  include Orx_gen.Graphic

  let get_size = get_vector get_size

  let get_origin = get_vector get_origin

  let to_structure (g : t) : Structure.t =
    let g' = Ctypes.to_voidp g in
    match Structure.of_void_pointer g' with
    | Some s -> s
    | None -> assert false
end

module Parent = struct
  type t =
    | Camera of Orx_gen.Camera.t
    | Object of Orx_gen.Object.t

  let set setter child (parent : t option) =
    let to_parent_ptr (p : t) =
      match p with
      | Camera c -> Orx_gen.Camera.to_void_pointer c
      | Object o -> Orx_gen.Object.to_void_pointer o
    in
    setter child (Option.map to_parent_ptr parent)

  let of_void_pointer p : t option =
    match Orx_gen.Object.of_void_pointer p with
    | Some o -> Some (Object o)
    | None ->
      ( match Orx_gen.Camera.of_void_pointer p with
      | Some c -> Some (Camera c)
      | None -> None
      )
end

module Camera = struct
  include Orx_gen.Camera

  let set_parent camera parent = Parent.set set_parent camera parent

  let get_parent camera =
    match get_parent camera with
    | None -> None
    | Some s -> Parent.of_void_pointer (Structure.to_void_pointer s)

  let get_position = get_vector get_position

  let create_from_config_exn = create_exn create_from_config "camera"
end

module Input = struct
  include Orx_gen.Input

  let get_binding (name : string) (index : int) =
    let type_ = Ctypes.allocate_n Orx_types.Input_type.t ~count:1 in
    let id = Ctypes.allocate_n Ctypes.int ~count:1 in
    let mode = Ctypes.allocate_n Orx_types.Input_mode.t ~count:1 in
    match get_binding name index type_ id mode with
    | Error _ as e -> Status.open_error e
    | Ok () -> Ok (!@type_, !@id, !@mode)
end

module Physics = struct
  include Orx_gen.Physics

  let get_gravity = get_vector_exn (fun () v -> get_gravity v)

  let check_collision_flag ~mask ~flag =
    Unsigned.UInt32.equal (Unsigned.UInt32.logand mask flag) flag
end

module Body_part = struct
  include Orx_gen.Body_part

  let set_self_flags part flags =
    set_self_flags part (Unsigned.UInt16.of_int flags)

  let get_self_flags part = get_self_flags part |> Unsigned.UInt16.to_int

  let set_check_mask part mask =
    set_check_mask part (Unsigned.UInt16.of_int mask)

  let get_check_mask part = get_check_mask part |> Unsigned.UInt16.to_int
end

module Body = struct
  include Orx_gen.Body

  let get_parts (body : t) : Body_part.t Seq.t =
    let rec iter prev_part () =
      match get_next_part body prev_part with
      | None -> Seq.Nil
      | Some next as part -> Seq.Cons (next, iter part)
    in
    iter None
end

module Object = struct
  include Orx_gen.Object

  type 'a associated_structure =
    | Body : Body.t associated_structure
    | Graphic : Graphic.t associated_structure
    | Sound : Sound.t associated_structure

  let get_structure (type s) (o : t) (s : s associated_structure) : s option =
    let ( let* ) = Option.bind in
    match s with
    | Body ->
      let* structure = get_structure o Body in
      Body.of_void_pointer (Structure.to_void_pointer structure)
    | Graphic ->
      let* structure = get_structure o Graphic in
      Graphic.of_void_pointer (Structure.to_void_pointer structure)
    | Sound ->
      let* structure = get_structure o Sound in
      Sound.of_void_pointer (Structure.to_void_pointer structure)

  let set_parent o parent =
    match Parent.set set_parent o parent with
    | Ok () -> ()
    | Error `Orx -> fail "Failed to set parent"

  let set_owner o owner = Parent.set set_owner o owner

  let get_repeat o =
    let x = Ctypes.allocate_n Ctypes.float ~count:1 in
    let y = Ctypes.allocate_n Ctypes.float ~count:1 in
    get_repeat o x y;
    (!@x, !@y)

  type collision = {
    colliding_object : t;
    contact : Vector.t;
    normal : Vector.t;
  }

  let get_bounding_box = get_obox_exn get_bounding_box

  let get_world_position = get_vector_exn get_world_position

  let get_position = get_vector_exn get_position

  let get_scale = get_vector_exn get_scale

  let get_speed = get_vector_exn get_speed

  let get_relative_speed = get_vector_exn get_relative_speed

  let get_custom_gravity = get_optional_vector get_custom_gravity

  let get_mass_center o =
    match get_optional_vector get_mass_center o with
    | Some v -> v
    | None -> invalid_arg Status.body_error_message

  let apply_force ?location o f = apply_force o f location
  let apply_impulse ?location o f = apply_impulse o f location

  let raycast
      ?(self_flags = 0xffff)
      ?(check_mask = 0xffff)
      ?(early_exit = false)
      (v0 : Vector.t)
      (v1 : Vector.t) : collision option =
    let contact = Vector.allocate_raw () in
    let normal = Vector.allocate_raw () in
    let collision =
      raycast v0 v1
        (Unsigned.UInt16.of_int self_flags)
        (Unsigned.UInt16.of_int check_mask)
        early_exit (Some contact) (Some normal)
    in
    match collision with
    | None -> None
    | Some o -> Some { colliding_object = o; contact; normal }

  type group =
    | All_groups
    | Group of string
    | Group_id of String_id.t

  let group_id group =
    match group with
    | All_groups -> String_id.undefined
    | Group name -> String_id.get_id name
    | Group_id id -> id

  let get_neighbor_list (box : Obox.t) group =
    match create_neighbor_list box (group_id group) with
    | None -> fail "Failed to allocate neighbor list"
    | Some bank ->
      let ptrs = Bank.to_list bank in
      let objects =
        List.map
          (fun p ->
            let ptr_ptr_void = Ctypes.from_voidp (Ctypes.ptr Ctypes.void) p in
            of_void_pointer !@ptr_ptr_void |> Option.get
            )
          ptrs
      in
      delete_neighbor_list bank;
      objects

  let pick v group = pick v (group_id group)

  let box_pick obox group = box_pick obox (group_id group)

  let set_group_id o group =
    match set_group_id o (group_id group) with
    | Ok () -> ()
    | Error `Orx -> fail "Failed to set group id"

  let set_group_id_recursive o group = set_group_id_recursive o (group_id group)

  let get_seq get_f =
    let rec iter last () : _ Seq.node =
      match get_f last with
      | None -> Nil
      | Some v as this -> Cons (v, iter this)
    in
    iter None

  let get_group (group : group) : t Seq.t =
    let group_id = group_id group in
    get_seq (fun o -> get_next o group_id)

  let get_enabled (group : group) : t Seq.t =
    let group_id = group_id group in
    get_seq (fun o -> get_next o group_id)

  type _ child =
    | Child_object : t child
    | Owned_object : t child
    | Child_camera : camera child

  let get_camera_children (o : t) : Camera.t Seq.t =
    get_seq (fun c ->
        let c = Option.map Camera.to_void_pointer c in
        let s = get_next_child o c Camera in
        let p = Option.map Structure.to_void_pointer s in
        Option.map Camera.of_void_pointer p |> Option.join
    )

  let get_object_children (o : t) : t Seq.t =
    get_seq (fun c ->
        let c = Option.map to_void_pointer c in
        let s = get_next_child o c Object in
        let p = Option.map Structure.to_void_pointer s in
        Option.map of_void_pointer p |> Option.join
    )

  let get_owned_children (o : t) : t Seq.t =
    let rec iter sibling () : _ Seq.node =
      match get_owned_sibling sibling with
      | None -> Nil
      | Some next -> Cons (next, iter next)
    in
    match get_owned_child o with
    | None -> Seq.empty
    | Some first -> fun () -> Cons (first, iter first)

  let get_children (type c) (o : t) (child : c child) : c Seq.t =
    match child with
    | Child_object -> get_object_children o
    | Owned_object -> get_owned_children o
    | Child_camera -> get_camera_children o

  let get_first_child (type c) (o : t) (child : c child) : c option =
    match child with
    | Child_object -> get_child o
    | Owned_object -> get_owned_child o
    | Child_camera ->
      get_next_child o None Camera
      |> Option.map Structure.to_void_pointer
      |> Option.map Camera.of_void_pointer
      |> Option.join

  let to_guid (o : t) : Structure.Guid.t =
    match to_void_pointer o |> Structure.of_void_pointer with
    | Some s -> Structure.get_guid s
    | None -> assert false

  let of_guid (guid : Structure.Guid.t) : t option =
    let ( let* ) = Option.bind in
    let* s = Structure.get guid in
    of_void_pointer (Ctypes.to_voidp s)

  (* Exception-raising variants of functions which use config names *)

  let create_from_config_exn = create_exn create_from_config "object"

  let add_fx_exn_wrapper add o name =
    add o name |> Status.raise "Unable to add FX %s" name
  let add_fx_exn = add_fx_exn_wrapper add_fx
  let add_unique_fx_exn = add_fx_exn_wrapper add_unique_fx
  let add_delayed_fx_exn o name delay =
    add_fx_exn_wrapper (fun o name -> add_delayed_fx o name delay) o name
  let remove_fx_exn o name =
    remove_fx o name |> Status.raise "Unable to remove FX %s" name
  let remove_all_fxs_exn o =
    remove_all_fxs o
    |> Status.raise "Unable to remove all FXs from %s" (get_name o)

  let add_shader_exn o name =
    add_shader o name |> Status.raise "Unable to add shader %s" name
  let remove_shader_exn o name =
    remove_shader o name |> Status.raise "Unable to remove shader %s" name

  let add_time_line_track_exn o name =
    add_time_line_track o name
    |> Status.raise "Unable to add time line track %s" name
  let remove_time_line_track_exn o name =
    remove_time_line_track o name
    |> Status.raise "Unable to remove time line track %s" name

  let set_target_anim_exn o name =
    set_target_anim o name
    |> Status.raise "Unable to set target animation %s" name

  let set_current_anim_exn o name =
    set_current_anim o name
    |> Status.raise "Unable to set target animation %s" name

  let add_sound_exn o name =
    add_sound o name |> Status.raise "Unable to add sound %s" name
  let remove_sound_exn o name =
    remove_sound o name |> Status.raise "Unable to remove sound %s" name

  let of_guid_exn guid =
    match of_guid guid with
    | Some o -> o
    | None ->
      Fmt.invalid_arg "Unable to find object with GUID %a" Structure.Guid.pp
        guid
end

module Event = struct
  include Orx_gen.Event

  type event_flag = Unsigned.UInt32.t

  let to_flag (event_id : 'a) (map_to_constant : ('a * int64) list) =
    match List.assoc_opt event_id map_to_constant with
    | None -> Fmt.invalid_arg "Unhandled event id when looking up flag"
    | Some event -> get_flag (Unsigned.UInt32.of_int64 event)

  let to_flags (event_ids : 'a list) (map_to_constant : ('a * int64) list) =
    let flags =
      List.map (fun event_id -> to_flag event_id map_to_constant) event_ids
    in
    List.fold_left
      (fun flag id -> Unsigned.UInt32.logor flag id)
      Unsigned.UInt32.zero flags

  let make_flags
      (type event payload)
      (event_type : (event, payload) Event_type.t)
      (event_ids : event list) : event_flag =
    match event_type with
    | Fx -> to_flags event_ids Orx_types.Fx_event.map_to_constant
    | Input -> to_flags event_ids Orx_types.Input_event.map_to_constant
    | Object -> to_flags event_ids Orx_types.Object_event.map_to_constant
    | Physics -> to_flags event_ids Orx_types.Physics_event.map_to_constant
    | Shader -> to_flags event_ids Orx_types.Shader_event.map_to_constant
    | Sound -> to_flags event_ids Orx_types.Sound_event.map_to_constant
    | Time_line -> to_flags event_ids Orx_types.Time_line_event.map_to_constant

  let all_events
      (type event payload)
      (event_type : (event, payload) Event_type.t) : event list =
    let firsts l = List.map fst l in
    match event_type with
    | Fx -> firsts Orx_types.Fx_event.map_to_constant
    | Input -> firsts Orx_types.Input_event.map_to_constant
    | Object -> firsts Orx_types.Object_event.map_to_constant
    | Physics -> firsts Orx_types.Physics_event.map_to_constant
    | Shader -> firsts Orx_types.Shader_event.map_to_constant
    | Sound -> firsts Orx_types.Sound_event.map_to_constant
    | Time_line -> firsts Orx_types.Time_line_event.map_to_constant

  let get_sender_object (event : t) : Object.t option =
    Object.of_void_pointer (Ctypes.getf !@event Orx_types.Event.sender)

  let get_recipient_object (event : t) : Object.t option =
    Object.of_void_pointer (Ctypes.getf !@event Orx_types.Event.recipient)

  let event_handler = Ctypes.(t @-> returning Orx_gen.Status.t)

  let c_add_handler =
    Ctypes.(
      Foreign.foreign "ml_orx_event_add_handler"
        (Orx_types.Event_type.t
        @-> Foreign.funptr event_handler
        @-> uint32_t
        @-> uint32_t
        @-> returning Orx_gen.Status.t
        )
    )

  let add_handler :
      type e p.
      ?events:e list -> (e, p) Event_type.t -> (t -> e -> p -> Status.t) -> unit
      =
   fun ?events event_type callback ->
    let callback event =
      let f =
        match event_type with
        | Fx ->
          fun () -> callback event (to_event event Fx) (to_payload event Fx)
        | Input ->
          fun () ->
            callback event (to_event event Input) (to_payload event Input)
        | Object ->
          fun () ->
            callback event (to_event event Object) (to_payload event Object)
        | Physics ->
          fun () ->
            callback event (to_event event Physics) (to_payload event Physics)
        | Shader ->
          fun () ->
            callback event (to_event event Shader) (to_payload event Shader)
        | Sound ->
          fun () ->
            callback event (to_event event Sound) (to_payload event Sound)
        | Time_line ->
          fun () ->
            callback event (to_event event Time_line)
              (to_payload event Time_line)
      in
      match f () with
      | result -> result
      | exception exn ->
        Fmt.epr "Unhandled exception in event callback: %a@." Fmt.exn_backtrace
          (exn, Printexc.get_raw_backtrace ());
        raise exn
    in
    Store.retain_permanently callback;
    let add_flags =
      match (event_type, events) with
      | ((Sound as et), None) -> make_flags et [ Start; Stop; Add; Remove ]
      | (et, Some es) -> make_flags et es
      | (et, None) -> make_flags et (all_events et)
    in
    let remove_flags = Unsigned.UInt32.max_int in
    let result =
      c_add_handler
        (Event_type.to_c_any event_type)
        callback add_flags remove_flags
    in
    match result with
    | Ok () -> ()
    | Error `Orx -> fail "Failed to set event callback"
end

module Clock = struct
  include Orx_gen.Clock

  let () =
    if
      Clock_info.assumed_clock_modifier_number
      <> Unsigned.Size_t.to_int Clock_info.clock_modifier_number
    then
      Fmt.failwith
        "orxCLOCK_MODIFIER_NUMBER is %d but the OCaml bindings expect it to be \
         %d - fix and recompile the bindings"
        (Unsigned.Size_t.to_int Clock_info.clock_modifier_number)
        Clock_info.assumed_clock_modifier_number

  let callback = Ctypes.(Info.t @-> ptr void @-> returning void)

  let c_register =
    Ctypes.(
      Foreign.foreign "orxClock_Register"
        (t
        @-> Foreign.funptr callback
        @-> ptr void
        @-> Orx_types.Module_id.t
        @-> Orx_types.Clock_priority.t
        @-> returning Orx_gen.Status.t
        )
    )

  let register (clock : t) callback module_ priority =
    let callback_wrapper info _ctx =
      match callback info with
      | () -> ()
      | exception exn ->
        Log.log "Unhandled exception in clock callback for clock %s: %a"
          (get_name clock) Fmt.exn_backtrace
          (exn, Printexc.get_raw_backtrace ());
        raise exn
    in
    Store.retain_permanently callback_wrapper;
    match c_register clock callback_wrapper Ctypes.null module_ priority with
    | Ok () -> ()
    | Error `Orx -> fail "Failed to set clock callback"

  let get_core () =
    match get "core" with
    | Some clock -> clock
    | None -> invalid_arg "Unable to get core clock"

  let create tick_size =
    match create tick_size with
    | Some clock -> clock
    | None -> failwith "Unable to allocate clock"

  let create_from_config_exn = create_exn create_from_config "clock"

  let c_add_timer =
    Ctypes.(
      Foreign.foreign "orxClock_AddTimer"
        (t
        @-> Foreign.funptr callback
        @-> float
        @-> int32_t
        @-> ptr void
        @-> returning Orx_gen.Status.t
        )
    )

  let add_timer clock callback delay repetition =
    let callback_wrapper info _ctx =
      match callback info with
      | () -> ()
      | exception exn ->
        Log.log "Unhandled exception in clock timer callback for clock %s: %a"
          (get_name clock) Fmt.exn_backtrace
          (exn, Printexc.get_raw_backtrace ());
        raise exn
    in
    c_add_timer clock callback_wrapper delay repetition Ctypes.null

  let add_timer_exn clock callback delay repetition =
    match add_timer clock callback delay repetition with
    | Ok () -> ()
    | Error `Orx ->
      Fmt.failwith "Failed to add timer to clock %s" (get_name clock)

  let c_remove_timer =
    Ctypes.(
      Foreign.foreign "orxClock_RemoveTimer"
        (t
        @-> ptr void (* Foreign.funptr callback *)
        @-> float
        @-> ptr void
        @-> returning Orx_gen.Status.t
        )
    )

  let remove_all_timers clock delay =
    c_remove_timer clock Ctypes.null delay Ctypes.null

  let remove_all_timers_exn clock delay =
    match remove_all_timers clock delay with
    | Ok () -> ()
    | Error `Orx ->
      Fmt.failwith "Failed to remove all timers with delay %f from clock %s"
        delay (get_name clock)
end

module Config = struct
  let wrap_get_vector = get_vector
  include Orx_gen.Config

  let load_from_memory s = load_from_memory s (String.length s)

  let bootstrap_function = Ctypes.(void @-> returning Orx_gen.Status.t)

  let set_bootstrap =
    Ctypes.(
      Foreign.foreign "orxConfig_SetBootstrap"
        (Foreign.funptr bootstrap_function @-> returning Orx_gen.Status.t)
    )

  let set_bootstrap f =
    match set_bootstrap f with
    | Ok () -> ()
    | Error `Orx -> fail "Unable to set config bootstrap function"

  let set_list_string (key : string) (values : string list) =
    let length = List.length values in
    let c_values = Ctypes.CArray.of_list Ctypes.string values in
    set_list_string key (Ctypes.CArray.start c_values) length

  let append_list_string (key : string) (values : string list) =
    let length = List.length values in
    let c_values = Ctypes.CArray.of_list Ctypes.string values in
    append_list_string key (Ctypes.CArray.start c_values) length

  let get_vector (key : string) : Vector.t = wrap_get_vector get_vector key

  let get_list_vector (key : string) (i : int option) : Vector.t =
    wrap_get_vector (fun k v -> get_list_vector k i v) key

  let if_has_value (key : string) (getter : string -> 'a) : 'a option =
    if has_value key then
      Some (getter key)
    else
      None

  let with_section (section : string) f =
    push_section section;
    Fun.protect ~finally:pop_section f

  let exists ~section ~key =
    has_section section && with_section section (fun () -> has_value key)

  let get (get : string -> 'a) ~(section : string) ~(key : string) : 'a =
    with_section section (fun () -> get key)

  let set
      (set : string -> 'a -> unit)
      (v : 'a)
      ~(section : string)
      ~(key : string) : unit =
    with_section section (fun () -> set key v)

  let get_seq (getter : string -> 'a) ~section ~key : 'a Seq.t =
    if exists ~section ~key then (
      let rec next () = Seq.Cons (get getter ~section ~key, next) in
      next
    ) else
      Seq.empty

  let get_list_item
      (get : string -> int option -> 'a)
      (i : int option)
      ~(section : string)
      ~(key : string) : 'a =
    with_section section (fun () -> get key i)

  let get_list
      (get : string -> int option -> 'a)
      ~(section : string)
      ~(key : string) : 'a list =
    let get_all () =
      let count = get_list_count key in
      List.init count (fun i -> get key (Some i))
    in
    with_section section get_all

  (* Helpers to get all the sections, or all the keys in a section *)
  let get_sections () : string list =
    let count = get_section_count () in
    List.init count (fun i -> get_section i)

  let get_current_section_keys () : string list =
    let count = get_key_count () in
    List.init count (fun i -> get_key i)

  let get_section_keys (section : string) =
    with_section section get_current_section_keys

  module Value = struct
    type _ t =
      | String : string t
      | Int : int t
      | Float : float t
      | Bool : bool t
      | Vector : Vector.t t
      | Guid : Structure.Guid.t t

    let to_proper_string (type v) (typ : v t) : string =
      match typ with
      | String -> "String"
      | Int -> "Int"
      | Float -> "Float"
      | Bool -> "Bool"
      | Vector -> "Vector"
      | Guid -> "GUID"

    let to_string typ = String.lowercase_ascii (to_proper_string typ)

    let get (type v) (typ : v t) ~section ~key : v =
      let getter : string -> v =
        match typ with
        | String -> get_string
        | Int -> get_int
        | Float -> get_float
        | Bool -> get_bool
        | Vector -> get_vector
        | Guid -> get_guid
      in
      get getter ~section ~key

    let set (type v) (typ : v t) (x : v) ~section ~key : unit =
      let setter : string -> v -> unit =
        match typ with
        | String -> set_string
        | Int -> set_int
        | Float -> set_float
        | Bool -> set_bool
        | Vector -> set_vector
        | Guid -> set_guid
      in
      set setter x ~section ~key
  end
end

module Command = struct
  include Orx_gen.Command

  module Var_type = struct
    type 'a t = 'a Config.Value.t

    let to_ctype (type s) (v : s t) : Orx_types.Command_var_type.t =
      match v with
      | String -> String
      | Float -> Float
      | Int -> Int
      | Bool -> Bool
      | Vector -> Vector
      | Guid -> Guid
  end

  module Var_def = struct
    include Orx_gen.Command_var_def

    let set_name (v : t) name =
      Ctypes.setf !@v Orx_types.Command_var_def.name name
    let set_type (v : t) type_ =
      Ctypes.setf !@v Orx_types.Command_var_def.type_ (Var_type.to_ctype type_)

    let make name type_ =
      let v : t = allocate_raw () in
      set_name v name;
      set_type v type_;
      v
  end

  module Var = struct
    include Orx_gen.Command_var

    let set (type s) (var : t) (var_type : s Var_type.t) (v : s) =
      set_type var (Var_type.to_ctype var_type);
      match var_type with
      | String -> set_string var v
      | Float -> set_float var v
      | Int -> set_int var v
      | Bool -> set_bool var v
      | Vector -> set_vector var !@v
      | Guid -> set_guid var v

    let make var_type v =
      let var = allocate_raw () in
      set var var_type v;
      var

    let get (type s) (var : t) (var_type : s Var_type.t) : s =
      (let actual_var_type = get_type var in
       let requested_var_type = Var_type.to_ctype var_type in
       let correct_type =
         Orx_types.Command_var_type.equal actual_var_type requested_var_type
       in
       if not correct_type then
         Log.log "Incorrect variable type when reading from command variable"
      );
      match var_type with
      | String -> get_string var
      | Float -> get_float var
      | Int -> get_int var |> Int64.to_int
      | Bool -> get_bool var
      | Vector ->
        let vec = get_vector var in
        Vector.make
          ~x:(Ctypes.getf vec Orx_types.Vector.x)
          ~y:(Ctypes.getf vec Orx_types.Vector.y)
          ~z:(Ctypes.getf vec Orx_types.Vector.z)
      | Guid -> get_guid var
  end

  let unregister_exn name =
    match unregister name with
    | Ok () -> ()
    | Error `Orx -> Fmt.invalid_arg "Unable to unregister command %s" name

  let command_handler = Ctypes.(uint32_t @-> Var.t @-> Var.t @-> returning void)

  let c_register =
    Ctypes.(
      Foreign.foreign "orxCommand_Register"
        (string
        @-> Foreign.funptr command_handler
        @-> int
        @-> int
        @-> Var_def.t
        @-> Var_def.t
        @-> returning Status.t
        )
    )

  let register
      name
      (f : Var.t array -> Var.t -> unit)
      (required_param_defs, optional_param_defs)
      return_def =
    let f_wrapper n_args (c_args : Var.t) (c_return : Var.t) =
      let n_args = Unsigned.UInt32.to_int n_args in
      let c_arg_array = Ctypes.CArray.from_ptr c_args n_args in
      let args =
        Array.init n_args (fun i ->
            Ctypes.CArray.get c_arg_array i |> Ctypes.addr
        )
      in
      f args c_return
    in
    let param_defs = List.append required_param_defs optional_param_defs in
    let c_param_defs =
      List.map Ctypes.( !@ ) param_defs
      |> Var_def.of_list
      |> Ctypes.CArray.start
    in
    Store.retain_permanently f_wrapper;
    c_register name f_wrapper
      (List.length required_param_defs)
      (List.length optional_param_defs)
      c_param_defs return_def

  let register_exn name f param_defs return_def =
    match register name f param_defs return_def with
    | Ok () -> ()
    | Error `Orx -> Fmt.invalid_arg "Unable to register command %s" name

  let evaluate command =
    let return = Var.allocate_raw () in
    let result : Var.t = evaluate command return in
    if Ctypes.is_null result then
      None
    else
      Some return

  let evaluate_with_guid command guid =
    let return = Var.allocate_raw () in
    let result : Var.t = evaluate_with_guid command guid return in
    if Ctypes.is_null result then
      None
    else
      Some return
end

module Orx_thread = struct
  let set_ocaml_callbacks =
    Ctypes.(
      Foreign.foreign "ml_orx_thread_set_callbacks" (void @-> returning void)
    )
end

module Main = struct
  let init_function = Ctypes.(void @-> returning Orx_gen.Status.t)

  let run_function = Ctypes.(void @-> returning Orx_gen.Status.t)

  let exit_function = Ctypes.(void @-> returning void)

  (* This is wrapped differently because the underlying orx function is *)
  (* inlined in orx.h *)
  let execute_c =
    Ctypes.(
      Foreign.foreign "ml_orx_execute"
        (int
        @-> ptr string
        @-> Foreign.funptr init_function
        @-> Foreign.funptr run_function
        @-> Foreign.funptr exit_function
        @-> returning void
        )
    )

  let execute ~init ~run ~exit () =
    (* Start the orx main loop *)
    let empty_argv = Ctypes.from_voidp Ctypes.string Ctypes.null in
    execute_c 0 empty_argv (Sys.opaque_identity init) (Sys.opaque_identity run)
      (Sys.opaque_identity exit)

  let start ?config_dir ?exit ~init ~run name =
    ( match config_dir with
    | None -> ()
    | Some dir ->
      let bootstrap () = Resource.add_storage Config dir false in
      Store.retain_permanently bootstrap;
      Config.set_bootstrap bootstrap
    );
    Config.set_basename name;
    let exit = Option.value exit ~default:(fun () -> ()) in
    Store.retain_permanently init;
    Store.retain_permanently run;
    Store.retain_permanently exit;
    execute ~init ~run ~exit ()
end
