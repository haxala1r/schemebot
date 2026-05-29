(lang dune 3.21)

(name schemebot)

(generate_opam_files true)
(source
 (github haxala1r/schemebot))

(authors "Emin Arslan <me@emin.engineer>")
(license LICENSE)

(documentation https://url/to/documentation)

(package
 (name schemebot)
 (synopsis "Bot for executing code as a Zulip bot.")
 (description "Executes code through chez scheme whenever invoked and responds with the result. Meant to be deployed on Google Cloud Run.")
 (depends ocaml cohttp-lwt-unix)
 (tags
  ("http" "scheme" "bot")))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/reference/dune-project/index.html
