
open Lwt
open Lwt.Syntax
open Cohttp
open Cohttp_lwt_unix

let port = int_of_string (Unix.getenv "PORT")

let write_to_tmp_file ext body =
  let s = "test."^ext in
  let* c = Lwt_io.open_file ~mode:(Lwt_io.Output) s in
  let* () = Lwt_io.write c body in
  let* () = Lwt_io.close c in
  Lwt.return s

let execute cmd args =
  let c = (cmd, args) in
  Lwt_process.pread ~timeout:15. ~env:(Unix.environment ()) c

let execute_lang lang file =
  match lang with
  | "haskell" -> execute "runghc" [|"runghc";file|]
  | "racket" -> execute "racket" [|"racket";"-f";file|]
  | "scheme" -> execute "scheme" [|"scheme"; "--script";file|]
  | "lua" -> execute "lua" [|"lua";file|]
  | "ruby" -> execute "ruby" [|"ruby";file|]
  | _ -> Lwt.return ("couldn't recognize language: "^lang)

let get_ext = function
  | "haskell" -> Some "hs"
  | "racket" -> Some "rkt"
  | "scheme" -> Some "scm"
  | "lua" -> Some "lua"
  | "ruby" -> Some "rb"
  | _ -> None

let push_and_run lang body =
  match (get_ext lang) with
  | Some ext ->
     let* s = write_to_tmp_file ext body in
     let* out = execute_lang lang s in
     Lwt.return out
  | None -> Lwt.return ("Unknown language: "^lang)

let split_code code =
  print_endline ("splitting: "^code);
  let pattern = Str.regexp "[ \r\n\t]" in
  let parts = Str.bounded_split pattern code 2 in
  match parts with
  | lang :: code :: _ -> Some (lang, code)
  | _ -> None

(* We need to parse the JSON info from the Zulip request to get the code to run
   as well as the authentication token, and the person sending the message...
 *)
let parse_body body =
  let ( let* ) = Option.bind in
  let member = Yojson.Basic.Util.member in
  let to_string_option = Yojson.Basic.Util.to_string_option in
  let json = Yojson.Basic.from_string body in
  let* data = json |> member "data" |> to_string_option in
  (* We Assume that the data is between ``` and ``` *)
  let pattern = Str.regexp "```" in
  let parts = Str.split pattern (" "^data) in
  (match parts with
  | _ :: code :: _ -> split_code code
  | _ -> None)

let construct_body strs =
  let strs = List.map Uri.pct_encode strs in
  String.concat "&" strs

let handle _conn req body =
  Lwt.catch (fun () ->
      let meth = req |> Request.meth |> Code.string_of_method in
      match meth with
      | "POST" ->
         let* body = Cohttp_lwt.Body.to_string body in
         (match parse_body body with
         | Some (lang, code) ->
            let* output = push_and_run lang code in
            let b = `Assoc [
                        ("content", `String output)
                      ] in
            let b = Yojson.Basic.to_string b in
            Server.respond_string ~status:`OK ~body:b ()
         | None -> Server.respond_string ~status:`OK ~body:"{\"content\":\"Invalid body\"}" ())
      | _ ->
         Server.respond_string ~status:`OK ~body:"Please make a post request." ())
    (fun exn ->
      let msg = Printexc.to_string exn in
      let backtrace = Printexc.get_backtrace () in
      Printf.eprintf "Request failed with exception: %s\nBacktrace:\n%s\n%!" msg backtrace;
      Server.respond_error ~status:`Internal_server_error ~body:"Internal Server Error" ()
    )

let server =
  Server.create ~mode:(`TCP (`Port port))
(Server.make ~callback:handle ())

let _ =
  print_endline "starting server";
  Lwt_main.run server
