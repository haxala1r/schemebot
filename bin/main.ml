
open Lwt
open Lwt.Syntax
open Cohttp
open Cohttp_lwt_unix

let port = int_of_string (Unix.getenv "PORT")

let write_to_tmp_file body =
  let* (s, c) = Lwt_io.open_temp_file () in
  let* () = Lwt_io.write c body in
  Lwt.return s

let execute cmd args =
  let c = (cmd, args) in
  Lwt_process.pread ~timeout:1. ~env:(Unix.environment ()) c
let push_and_run body =
  print_endline "test1";
  let* s = write_to_tmp_file body in
  print_endline "test2";
  let* out = execute "scheme" [|"scheme"; "--script"; s|] in
  print_endline "test3";
  print_endline ("got output: "^out);
  Lwt.return out

type recipient =
  | Channel of int * string
  | Direct of int

(* We need to parse the JSON info from the Zulip request to get the code to run
   as well as the authentication token, and the person sending the message...
 *)
let parse_body body =
  let ( let* ) = Option.bind in
  let member = Yojson.Basic.Util.member in
  let to_string_option = Yojson.Basic.Util.to_string_option in
  let to_int_option = Yojson.Basic.Util.to_int_option in
  let json = Yojson.Basic.from_string body in
  let getstr s = json |> member s |> to_string_option in
  let msgobj = json |> member "message" in
  print_endline "heck";
  let* r = (match msgobj |> member "type" |> to_string_option with
          | Some "stream" ->
             print_endline "stream!";
             let* id = msgobj |> member "stream_id" |> to_int_option in
             let* topic = msgobj |> member "subject" |> to_string_option in
             Some (Channel (id, topic))
          | Some "private" ->
             print_endline "direct!";
             let* id = msgobj |> member "sender_id" |> to_int_option in
             Some (Direct id)
          | _ -> None) in
  let* data = getstr "data" in
  let* email = getstr "bot_email" in
  let* token = getstr "token" in
  
  (* We Assume that the data is between ```scheme and ``` *)
  let pattern = Str.regexp "```[a-zA-Z]*\n?" in
  let parts = Str.split pattern (" "^data) in
  (match parts with
  | _ :: code :: _ -> Some (code, r, email, token)
  | _ -> None)

let construct_body strs =
  let strs = List.map Uri.pct_encode strs in
  String.concat "&" strs


let send_msg r email token content =
  let body = match r with
    |Channel (i, topic) ->
      construct_body ["type=stream"; "to="^(string_of_int i);"topic="^topic; "content=```\n"^content^"\n```"]
    | Direct i ->
       construct_body ["type=direct"; "to=["^(string_of_int i)^"]"; "content="^content]
  in
  let body = Cohttp_lwt.Body.of_string (body^"\r\n") in
  let auth = (match Base64.encode (email^":"^token) with
             | Ok s -> s
             | _ -> failwith "base64 encode failed?") in
  let headers = Header.init () in
  let headers = Header.add headers "Authorization" ("Basic "^auth) in
  let headers = Header.add headers "Content-Type" "application/x-www-form-urlencoded" in
  let* (_response, body) = Cohttp_lwt_unix.Client.post ~headers ~body:body (Uri.of_string "https://zulip.fnpl.rocks/api/v1/messages") in
  let* body =Cohttp_lwt.Body.to_string body in
  print_endline ("got: "^body);
  Lwt.return body


let handle _conn req body =
  let meth = req |> Request.meth |> Code.string_of_method in
  match meth with
  | "POST" ->
     let* body = Cohttp_lwt.Body.to_string body in
     (match parse_body body with
     | Some (body, recipient, email, token) ->
        print_endline ("body:"^body);
        let* output = push_and_run body in
        let* b = send_msg recipient email token output in
        Server.respond_string ~status:`OK ~body:b ()
     | None -> Server.respond_string ~status:`OK ~body:"Invalid body" ())
  | _ ->
     Server.respond_string ~status:`OK ~body:"Please make a post request." ()

let server =
  Server.create ~mode:(`TCP (`Port port))
(Server.make ~callback:handle ())

let _ =
  print_endline "starting server";
  Lwt_main.run server
