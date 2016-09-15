(* Ocsigen
 * Copyright (C) 2005-2008 Vincent Balat, Stéphane Glondu
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, with linking exception;
 * either version 2.1 of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.
*)

exception Ocsigen_Internal_Error of string
exception Input_is_too_large
exception Ocsigen_Bad_Request
exception Ocsigen_Request_too_long

external id : 'a -> 'a = "%identity"

let (>>=) = Lwt.bind
let (>|=) = Lwt.(>|=)
let (!!) = Lazy.force

let (|>) x f = f x
let (@@) f x = f x

let comp f g x = f (g x)
let curry f x y = f (x, y)
let uncurry f (x, y) = f x y

type poly
external to_poly : 'a -> poly = "%identity"
external from_poly : poly -> 'a = "%identity"

module Tuple3 = struct
  let fst (a, _, _) = a
  let snd (_, a, _) = a
  let thd (_, _, a) = a
end

type yesnomaybe = Yes | No | Maybe
type ('a, 'b) leftright = Left of 'a | Right of 'b

let advert = "Page generated by OCaml with Ocsigen.
See http://ocsigen.org/ and http://caml.inria.fr/ for information"

(*****************************************************************************)

module Option = struct
  type 'a t = 'a option
  let map f = function
    | Some x -> Some (f x)
    | None -> None
  let get f = function
    | Some x -> x
    | None -> f ()
  let get' a = function
    | Some x -> x
    | None -> a
  let iter f = function
    | Some x -> f x
    | None -> ()
  let return x =
    Some x
  let bind opt k =
    match opt with
    | Some x -> k x
    | None -> None
  let to_list = function
    | None -> []
    | Some v -> [v]
  module Lwt = struct
    let map f = function
      | Some x -> lwt v = f x in Lwt.return (Some v)
      | None -> Lwt.return None
    let get f = function
      | Some x -> Lwt.return x
      | None -> f ()
    let get' a = function
      | Some x -> Lwt.return x
      | None -> a
    let iter f = function
      | Some x -> f x
      | None -> Lwt.return ()
    let bind opt k =
      match opt with
      | Some x -> k x
      | None -> Lwt.return None
  end
end

module List = struct

  include List

  let map_filter f l =
    let rec aux acc = function
      | [] -> acc
      | t::q ->
        match f t with
        | None -> aux acc q
        | Some r -> aux (r::acc) q
    in
    List.rev (aux [] l)

  let rec remove_first_if_any a = function
    |  [] -> []
    | b::l when a = b -> l
    | b::l -> b::(remove_first_if_any a l)

  let rec remove_first_if_any_q a = function
    |  [] -> []
    | b::l when a == b -> l
    | b::l -> b::(remove_first_if_any_q a l)

  let rec remove_first a = function
    |  [] -> raise Not_found
    | b::l when a = b -> l
    | b::l -> b::(remove_first a l)

  let rec remove_first_q a = function
    | [] -> raise Not_found
    | b::l when a == b -> l
    | b::l -> b::(remove_first_q a l)

  let rec remove_all a = function
    | [] -> []
    | b::l when a = b -> remove_all a l
    | b::l -> b::(remove_all a l)

  let rec remove_all_q a = function
    | [] -> []
    | b::l when a == b -> remove_all_q a l
    | b::l -> b::(remove_all_q a l)

  let rec remove_all_assoc a = function
    | [] -> []
    | (b, _)::l when a = b -> remove_all_assoc a l
    | b::l -> b::(remove_all_assoc a l)

  let rec remove_all_assoc_q a = function
    | [] -> []
    | (b,_)::l when a == b -> remove_all_assoc_q a l
    | b::l -> b::(remove_all_assoc_q a l)

  let rec last = function
    |  [] -> raise Not_found
    | [b] -> b
    | _::l -> last l

  let rec assoc_remove a = function
    | [] -> raise Not_found
    | (b, c)::l when a = b -> c, l
    | b::l -> let v, ll = assoc_remove a l in (v, b::ll)

  let rec is_prefix l1 l2 =
    match (l1, l2) with
    | [], _ -> true
    | a::ll1, b::ll2 when a=b -> is_prefix ll1 ll2
    | _ -> false

  let rec chop n xs =
    if n <= 0
    then xs
    else
      match xs with
      | [] -> []
      | x :: xs -> chop (n-1) xs

end

(*****************************************************************************)

(* circular lists *)
module Clist  : sig

  type 'a t
  type 'a node
  val make : 'a -> 'a node
  val create : unit -> 'a t
  val insert : 'a t -> 'a node -> unit
  val remove : 'a node -> unit
  val value : 'a node -> 'a
  val in_list : 'a node -> bool
  val is_empty : 'a t -> bool
  val iter : ('a -> unit) -> 'a t -> unit
  val fold_left : ('a -> 'b -> 'a) -> 'a -> 'b t -> 'a

end = struct

  type 'a node =
    { content : 'a option;
      mutable prev : 'a node;
      mutable next : 'a node }

  type 'a t = 'a node

  let make' c =
    let rec x = { content = c; prev = x; next = x } in
    x

  let make c = make' (Some c)

  let create () = make' None

  let insert p x =
    let n = p.next in
    p.next <- x;
    x.prev <- p;
    x.next <- n;
    n.prev <- x

  let remove x =
    let p = x.prev in
    let n = x.next in
    p.next <- n;
    n.prev <- p;
    x.next <- x;
    x.prev <- x

  let in_list x = x.next != x

  let is_empty set = set.next == set

  let value c =
    match c.content with
    | None -> failwith "Clist.value"
    | Some c -> c

  let rec iter f (node : 'a t) =
    match node.next.content with
    | Some c ->
      f c;
      iter f node.next
    | None -> ()

  let rec fold_left f a (node : 'a t) =
    match node.next.content with
    | Some c ->  fold_left f (f a c) node.next
    | None -> a

end

(*****************************************************************************)

module Int = struct

  module Table = Map.Make(struct
      type t = int
      let compare = compare
    end)

end

(*****************************************************************************)

module String_base = struct

  include String

  (* Returns a copy of the string from beg to endd,
     removing spaces at the beginning and at the end *)
  let remove_spaces s beg endd =
    let rec find_not_space s i step =
      if (i > endd) || (beg > i)
      then i
      else
      if s.[i] = ' '
      then find_not_space s (i+step) step
      else i
    in
    let first = find_not_space s beg 1 in
    let last = find_not_space s endd (-1) in
    if last >= first
    then String.sub s first (1+ last - first)
    else ""

  (* Cut a string to the next separator *)
  let basic_sep char s =
    try
      let seppos = String.index s char in
      ((String.sub s 0 seppos),
       (String.sub s (seppos+1)
          ((String.length s) - seppos - 1)))
    with Invalid_argument _ -> raise Not_found

  (* Cut a string to the next separator, removing spaces.
     Raises Not_found if the separator connot be found.
  *)
  let sep char s =
    let len = String.length s in
    let seppos = String.index s char in
    ((remove_spaces s 0 (seppos-1)),
     (remove_spaces s (seppos+1) (len-1)))

  (* splits a string, for ex "azert,   sdfmlskdf,    dfdsfs" *)
  let rec split ?(multisep=false) char s =
    let longueur = String.length s in
    let rec aux deb =
      if deb >= longueur
      then []
      else
        try
          let firstsep = String.index_from s deb char in
          if multisep && firstsep = deb then
            aux (deb + 1)
          else
            (remove_spaces s deb (firstsep-1))::
            (aux (firstsep+1))
        with Not_found -> [remove_spaces s deb (longueur-1)]
    in
    aux 0

  let may_append s1 ~sep = function
    | "" -> s1
    | s2 -> s1^sep^s2

  let may_concat s1 ~sep s2 = match s1, s2 with
    | _, "" -> s1
    | "", _ -> s2
    | _ -> String.concat sep [s1;s2]


  (* returns the index of the first difference between s1 and s2,
     starting from n and ending at last.
     returns (last + 1) if no difference is found.
  *)
  let rec first_diff s1 s2 n last =
    try
      if s1.[n] = s2.[n]
      then
        if n = last
        then last+1
        else first_diff s1 s2 (n+1) last
      else n
    with Invalid_argument _ -> n

  module Table = Map.Make(String)
  module Set = Set.Make(String)
  module Map = Map.Make(String)

end

(*****************************************************************************)

module Url_base = struct

  type t = string
  type uri = string
  type path = string list

  let make_absolute_url ~https ~host ~port uri =
    (if https
     then "https://"
     else "http://"
    )^
    host^
    (if (port = 80 && not https) || (https && port = 443)
     then ""
     else ":"^string_of_int port)^
    uri


  let remove_dotdot = (* removes "../" *)
    let rec aux = function
      | [] -> []
      | [""] as l -> l
      (*    | ""::l -> aux l *) (* we do not remove "//" any more,
                                   because of optional suffixes in Eliom *)
      | ".."::l -> aux l
      | a::l -> a::(aux l)
    in function
      | [] -> []
      | ""::l -> ""::(aux l)
      | l -> aux l

  let remove_end_slash s =
    try
      if s.[(String.length s) - 1] = '/'
      then String.sub s 0 ((String.length s) - 1)
      else s
    with Invalid_argument _ -> s


  let remove_internal_slash u =
    let rec aux = function
      | [] -> []
      | [a] -> [a]
      | ""::l -> aux l
      | a::l -> a::(aux l)
    in match u with
    | [] -> []
    | a::l -> a::(aux l)

  let change_empty_list = function
    | [] -> [""] (* It is not possible to register an empty URL *)
    | l -> l

  let rec add_end_slash_if_missing = function
    | [] -> [""]
    | [""] as a -> a
    | a::l -> a::(add_end_slash_if_missing l)

  let rec remove_slash_at_end = function
    | []
    | [""] -> []
    | a::l -> a::(remove_slash_at_end l)

  let remove_slash_at_beginning = function
    | [] -> []
    | [""] -> [""]
    | ""::l -> l
    | l -> l

  let rec recursively_remove_slash_at_beginning = function
    | [] -> []
    | [""] -> [""]
    | ""::l -> recursively_remove_slash_at_beginning l
    | l -> l

  let rec is_prefix_skip_end_slash l1 l2 =
    match (l1, l2) with
    | [""], _
    | [], _ -> true
    | a::ll1, b::ll2 when a=b -> is_prefix_skip_end_slash ll1 ll2
    | _ -> false


  let split_fragment s =
    try
      let pos = String.index s '#' in
      String.sub s 0 pos,
      Some (String.sub s (pos+1) (String.length s - 1 - pos))
    with Not_found -> s, None

end

(************************************************************************)

module Printexc = struct

  include Printexc

  let exc_printer = ref (fun _ e -> Printexc.to_string e)

  let rec to_string e = !exc_printer to_string e

  let register_exn_printer p =
    let printer =
      let old = !exc_printer in
      (fun f_rec s ->
         try p f_rec s
         with e -> old f_rec s) in
    exc_printer := printer

end

(*****************************************************************************)

let debug = prerr_endline
