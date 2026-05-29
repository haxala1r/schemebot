
open Lwt
open Cohttp_lwt_unix


let handle _conn _req _body =
  Server.respond_string ~status:`OK ~body:"Hello world!" ()

let server =
  Server.create ~mode:(`TCP (`Port (int_of_string (Sys.getenv "PORT"))))
(Server.make ~callback:handle ())



let _ =
  print_endline "starting server";
  Lwt_main.run server
