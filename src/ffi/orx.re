let (!@) = Ctypes.(!@);

let orx_error = (name: string) => {
  Fmt.invalid_arg("Fatal orx error in %s", name);
};

module Orx_gen = Orx_bindings.Bindings(Generated);

module Input = Orx_gen.Input;
module Vector = Orx_gen.Vector;
module Resource = Orx_gen.Resource;
module Viewport = Orx_gen.Viewport;

module Object = {
  include Orx_gen.Object;

  let get_world_position = (o: t): Vector.t => {
    let pos = Vector.allocate_raw();
    let pos' = get_world_position(o, pos);
    if (Ctypes.is_null(pos')) {
      orx_error("get_world_position");
    } else {
      Vector.of_raw(pos);
    };
  };

  let set_position = (o: t, v: Vector.t): unit => {
    switch (set_position(o, v)) {
    | Ok () => ()
    | Error () => orx_error("set_position")
    };
  };

  let set_text_string = (o: t, s: string): unit => {
    switch (set_text_string(o, s)) {
    | Ok () => ()
    | Error () => orx_error("set_text_string")
    };
  };
};

module Event = {
  include Orx_gen.Event;

  let event_handler = Ctypes.(t @-> returning(Orx_gen.Status.t));

  let add_handler =
    Ctypes.(
      Foreign.foreign(
        "orxEvent_AddHandler",
        Orx_types.Event_type.t
        @-> Foreign.funptr(event_handler)
        @-> returning(Orx_gen.Status.t),
      )
    );
};

module Config = {
  include Orx_gen.Config_generated;
  let bootstrap_function = Ctypes.(void @-> returning(Orx_gen.Status.t));

  let set_bootstrap =
    Ctypes.(
      Foreign.foreign(
        "orxConfig_SetBootstrap",
        Foreign.funptr(bootstrap_function) @-> returning(Orx_gen.Status.t),
      )
    );
};

module Main = {
  let init_function = Ctypes.(void @-> returning(Orx_gen.Status.t));
  let run_function = Ctypes.(void @-> returning(Orx_gen.Status.t));
  let exit_function = Ctypes.(void @-> returning(void));

  // This is wrapped differently because it's inlined in orx.h
  let execute_c = {
    Ctypes.(
      Foreign.foreign(
        "ml_orx_execute",
        int
        @-> ptr(string)
        @-> Foreign.funptr(init_function)
        @-> Foreign.funptr(run_function)
        @-> Foreign.funptr(exit_function)
        @-> returning(void),
      )
    );
  };

  let execute = (~init, ~run, ~exit, ()) => {
    let empty_argv = Ctypes.from_voidp(Ctypes.string, Ctypes.null);
    execute_c(0, empty_argv, init, run, exit);
  };
};
