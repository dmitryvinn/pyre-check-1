(*
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *)

open OUnit2
open Core
open Ast
open Server
open Pyre
open Test

let test_parse_query context =
  let assert_parses serialized query =
    let type_query_request_equal left right =
      let expression_equal left right = Expression.location_insensitive_compare left right = 0 in
      match left, right with
      | ( Query.Request.IsCompatibleWith (left_first, left_second),
          Query.Request.IsCompatibleWith (right_first, right_second) )
      | LessOrEqual (left_first, left_second), LessOrEqual (right_first, right_second) ->
          expression_equal left_first right_first && expression_equal left_second right_second
      | Superclasses left, Superclasses right ->
          List.for_all2_exn ~f:(fun left right -> Reference.equal left right) left right
      | Type left, Type right -> expression_equal left right
      | _ -> Query.Request.equal left right
    in
    assert_equal
      ~ctxt:context
      ~cmp:type_query_request_equal
      ~printer:Query.Request.show
      query
      (Query.parse_query serialized)
  in
  let assert_fails_to_parse serialized =
    try
      Query.parse_query serialized |> ignore;
      assert_unreached ()
    with
    | Query.InvalidQuery _ -> ()
  in
  let ( ! ) name =
    let open Expression in
    Expression.Name (Name.Identifier name) |> Node.create_with_default_location
  in
  assert_parses "less_or_equal(int, bool)" (LessOrEqual (!"int", !"bool"));
  assert_parses "less_or_equal (int, bool)" (LessOrEqual (!"int", !"bool"));
  assert_parses "less_or_equal(  int, int)" (LessOrEqual (!"int", !"int"));
  assert_parses "Less_Or_Equal(  int, int)" (LessOrEqual (!"int", !"int"));
  assert_parses "is_compatible_with(int, bool)" (IsCompatibleWith (!"int", !"bool"));
  assert_parses "is_compatible_with (int, bool)" (IsCompatibleWith (!"int", !"bool"));
  assert_parses "is_compatible_with(  int, int)" (IsCompatibleWith (!"int", !"int"));
  assert_parses "Is_Compatible_With(  int, int)" (IsCompatibleWith (!"int", !"int"));
  assert_fails_to_parse "less_or_equal()";
  assert_fails_to_parse "less_or_equal(int, int, int)";
  assert_fails_to_parse "less_or_eq(int, bool)";
  assert_fails_to_parse "is_compatible_with()";
  assert_fails_to_parse "is_compatible_with(int, int, int)";
  assert_fails_to_parse "iscompatible(int, bool)";
  assert_fails_to_parse "IsCompatibleWith(int, bool)";
  assert_fails_to_parse "meet(int, int, int)";
  assert_fails_to_parse "meet(int)";
  assert_fails_to_parse "join(int)";
  assert_parses "superclasses(int)" (Superclasses [!&"int"]);
  assert_parses "superclasses(int, bool)" (Superclasses [!&"int"; !&"bool"]);
  assert_parses "type(C)" (Type !"C");
  assert_parses "type((C,B))" (Type (+Expression.Expression.Tuple [!"C"; !"B"]));
  assert_fails_to_parse "type(a.b, c.d)";
  assert_fails_to_parse "typecheck(1+2)";
  assert_parses "types(path='a.py')" (TypesInFiles ["a.py"]);
  assert_parses "types('a.py')" (TypesInFiles ["a.py"]);
  assert_fails_to_parse "types(a.py:1:2)";
  assert_fails_to_parse "types(a.py)";
  assert_fails_to_parse "types('a.py', 1, 2)";
  assert_parses "attributes(C)" (Attributes !&"C");
  assert_fails_to_parse "attributes(C, D)";
  assert_parses
    "save_server_state('state')"
    (SaveServerState (Path.create_absolute ~follow_symbolic_links:false "state"));
  assert_fails_to_parse "save_server_state(state)";
  assert_parses "path_of_module(a.b.c)" (PathOfModule !&"a.b.c");
  assert_fails_to_parse "path_of_module('a.b.c')";
  assert_fails_to_parse "path_of_module(a.b, b.c)";
  assert_parses "validate_taint_models()" (ValidateTaintModels None);
  assert_parses "validate_taint_models('foo.py')" (ValidateTaintModels (Some "foo.py"));
  assert_parses "defines(a.b)" (Defines [Reference.create "a.b"]);
  assert_parses "batch()" (Batch []);
  assert_fails_to_parse "batch(batch())";
  assert_fails_to_parse "batch(defines(a.b), invalid(a))";
  assert_parses "batch(defines(a.b))" (Batch [Defines [Reference.create "a.b"]]);
  assert_parses
    "batch(defines(a.b), types(path='a.py'))"
    (Batch [Defines [Reference.create "a.b"]; TypesInFiles ["a.py"]])


let () = "query" >::: ["parse_query" >:: test_parse_query] |> Test.run