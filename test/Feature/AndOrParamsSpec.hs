module Feature.AndOrParamsSpec where
import Test.Hspec
import Test.Hspec.Wai
import Test.Hspec.Wai.JSON
import Network.HTTP.Types

import Network.Wai (Application)

import SpecHelper
import Protolude hiding (get)


spec :: SpecWith Application
spec =
  describe "and/or params used for complex boolean logic" $ do
    context "used with GET" $ do
      context "or param" $ do
        it "can do simple logic" $
          get "/entities?or=(id.eq.1,id.eq.2)&select=id" `shouldRespondWith`
            [json|[{ "id": 1 }, { "id": 2 }]|] { matchHeaders = [matchContentTypeJson] }
        it "can negate simple logic" $
          get "/entities?not.or=(id.eq.1,id.eq.2)&select=id" `shouldRespondWith`
            [json|[{ "id": 3 }, { "id": 4 }]|] { matchHeaders = [matchContentTypeJson] }
        it "can be combined with traditional filters" $
          get "/entities?or=(id.eq.1,id.eq.2)&name=eq.entity 1&select=id" `shouldRespondWith`
            [json|[{ "id": 1 }]|] { matchHeaders = [matchContentTypeJson] }

      context "embedded levels" $ do
        it "can do logic on the second level" $
          get "/entities?child_entities.or=(id.eq.1,name.eq.child entity 2)&select=id,child_entities{id}" `shouldRespondWith`
            [json|[
              {"id": 1, "child_entities": [ { "id": 1 }, { "id": 2 } ] }, { "id": 2, "child_entities": []},
              {"id": 3, "child_entities": []}, {"id": 4, "child_entities": []}
            ]|] { matchHeaders = [matchContentTypeJson] }
        it "can do logic on the third level" $
          get "/entities?child_entities.grandchild_entities.or=(id.eq.1,id.eq.2)&select=id,child_entities{id,grandchild_entities{id}}" `shouldRespondWith`
            [json|[
              {"id": 1, "child_entities": [ { "id": 1, "grandchild_entities": [ { "id": 1 }, { "id": 2 } ]}, { "id": 2, "grandchild_entities": []}]},
              {"id": 2, "child_entities": [ { "id": 3, "grandchild_entities": []} ]},
              {"id": 3, "child_entities": []}, {"id": 4, "child_entities": []}
            ]|] { matchHeaders = [matchContentTypeJson] }

      context "and/or params combined" $ do
        it "can be nested inside the same expression" $
          get "/entities?or=(and(name.eq.entity 2,id.eq.2),and(name.eq.entity 1,id.eq.1))&select=id" `shouldRespondWith`
            [json|[{ "id": 1 }, { "id": 2 }]|] { matchHeaders = [matchContentTypeJson] }
        it "can be negated while nested" $
          get "/entities?or=(not.and(name.eq.entity 2,id.eq.2),not.and(name.eq.entity 1,id.eq.1))&select=id" `shouldRespondWith`
            [json|[{ "id": 1 }, { "id": 2 }, { "id": 3 }, { "id": 4 }]|] { matchHeaders = [matchContentTypeJson] }
        it "can be combined unnested" $
          get "/entities?and=(id.eq.1,name.eq.entity 1)&or=(id.eq.1,id.eq.2)&select=id" `shouldRespondWith`
            [json|[{ "id": 1 }]|] { matchHeaders = [matchContentTypeJson] }

      context "operators inside and/or" $ do
        it "can handle eq and neq" $
          get "/entities?and=(id.eq.1,id.neq.2))&select=id" `shouldRespondWith`
            [json|[{ "id": 1 }]|] { matchHeaders = [matchContentTypeJson] }
        it "can handle lt and gt" $
          get "/entities?or=(id.lt.2,id.gt.3)&select=id" `shouldRespondWith`
            [json|[{ "id": 1 }, { "id": 4 }]|] { matchHeaders = [matchContentTypeJson] }
        it "can handle lte and gte" $
          get "/entities?or=(id.lte.2,id.gte.3)&select=id" `shouldRespondWith`
            [json|[{ "id": 1 }, { "id": 2 }, { "id": 3 }, { "id": 4 }]|] { matchHeaders = [matchContentTypeJson] }
        it "can handle like and ilike" $
          get "/entities?or=(name.like.*1,name.ilike.*ENTITY 2)&select=id" `shouldRespondWith`
            [json|[{ "id": 1 }, { "id": 2 }]|] { matchHeaders = [matchContentTypeJson] }
        it "can handle in" $
          get "/entities?or=(id.in.(1,2),id.in.(3,4))&select=id" `shouldRespondWith`
            [json|[{ "id": 1 }, { "id": 2 }, { "id": 3 }, { "id": 4 }]|] { matchHeaders = [matchContentTypeJson] }
        it "can handle is" $
          get "/entities?and=(name.is.null,arr.is.null)&select=id" `shouldRespondWith`
            [json|[{ "id": 4 }]|] { matchHeaders = [matchContentTypeJson] }
        it "can handle @@" $
          get "/entities?or=(text_search_vector.@@.bar,text_search_vector.@@.baz)&select=id" `shouldRespondWith`
            [json|[{ "id": 1 }, { "id": 2 }]|] { matchHeaders = [matchContentTypeJson] }
        it "can handle @> and <@" $
          get "/entities?or=(arr.@>.{1,2,3},arr.<@.{1})&select=id" `shouldRespondWith`
            [json|[{ "id": 1 },{ "id": 3 }]|] { matchHeaders = [matchContentTypeJson] }
        context "operators with not" $ do
          it "eq, @>, like can be negated" $
            get "/entities?and=(arr.not.@>.{1,2,3},and(id.not.eq.2,name.not.like.*3))&select=id" `shouldRespondWith`
              [json|[{ "id": 1}]|] { matchHeaders = [matchContentTypeJson] }
          it "in, is, @@ can be negated" $
            get "/entities?and=(id.not.in.(1,3),and(name.not.is.null,text_search_vector.not.@@.foo))&select=id" `shouldRespondWith`
              [json|[{ "id": 2}]|] { matchHeaders = [matchContentTypeJson] }
          it "lt, gte, <@ can be negated" $
            get "/entities?and=(arr.not.<@.{1},or(id.not.lt.1,id.not.gte.3))&select=id" `shouldRespondWith`
              [json|[{"id": 2}, {"id": 3}]|] { matchHeaders = [matchContentTypeJson] }
          it "gt, lte, ilike can be negated" $
            get "/entities?and=(name.not.ilike.*ITY2,or(id.not.gt.4,id.not.lte.1))&select=id" `shouldRespondWith`
              [json|[{"id": 1}, {"id": 2}, {"id": 3}]|] { matchHeaders = [matchContentTypeJson] }

      context "and/or params with quotes" $ do
        it "eq can have quotes" $
          get "/grandchild_entities?or=(name.eq.\"(grandchild,entity,4)\",name.eq.\"(grandchild,entity,5)\")&select=id" `shouldRespondWith`
            [json|[{ "id": 4 }, { "id": 5 }]|] { matchHeaders = [matchContentTypeJson] }
        it "like and ilike can have quotes" $
          get "/grandchild_entities?or=(name.like.\"*ity,4*\",name.ilike.\"*ITY,5)\")&select=id" `shouldRespondWith`
            [json|[{ "id": 4 }, { "id": 5 }]|] { matchHeaders = [matchContentTypeJson] }
        it "in can have quotes" $
          get "/grandchild_entities?or=(id.in.(\"1\",\"2\"),id.in.(\"3\",\"4\"))&select=id" `shouldRespondWith`
            [json|[{ "id": 1 }, { "id": 2 }, { "id": 3 }, { "id": 4 }]|] { matchHeaders = [matchContentTypeJson] }

      it "allows whitespace" $
        get "/entities?and=( and ( id.in.( 1, 2, 3 ) , id.eq.3 ) , or ( id.eq.2 , id.eq.3 ) )&select=id" `shouldRespondWith`
          [json|[{ "id": 3 }]|] { matchHeaders = [matchContentTypeJson] }

      context "multiple and/or conditions" $ do
        it "cannot have zero conditions" $
          get "/entities?or=()" `shouldRespondWith`
            [json|{
              "details": "unexpected \")\" expecting field name (* or [a..z0..9_]), negation operator (not) or logic operator (and, or)",
              "message": "\"failed to parse logic tree (())\" (line 1, column 4)"
            }|] { matchStatus = 400, matchHeaders = [matchContentTypeJson] }
        it "can have a single condition" $ do
          get "/entities?or=(id.eq.1)&select=id" `shouldRespondWith`
            [json|[{"id":1}]|] { matchHeaders = [matchContentTypeJson] }
          get "/entities?and=(id.eq.1)&select=id" `shouldRespondWith`
            [json|[{"id":1}]|] { matchHeaders = [matchContentTypeJson] }
        it "can have three conditions" $ do
          get "/grandchild_entities?or=(id.eq.1, id.eq.2, id.eq.3)&select=id" `shouldRespondWith`
            [json|[{"id":1}, {"id":2}, {"id":3}]|] { matchHeaders = [matchContentTypeJson] }
          get "/grandchild_entities?and=(id.in.(1,2), id.in.(3,1), id.in.(1,4))&select=id" `shouldRespondWith`
            [json|[{"id":1}]|] { matchHeaders = [matchContentTypeJson] }
        it "can have four conditions combining and/or" $ do
          get "/grandchild_entities?or=( id.eq.1, id.eq.2, and(id.in.(1,3), id.in.(2,3)), id.eq.4 )&select=id" `shouldRespondWith`
            [json|[{"id":1}, {"id":2}, {"id":3}, {"id":4}]|] { matchHeaders = [matchContentTypeJson] }
          get "/grandchild_entities?and=( id.eq.1, not.or(id.eq.2, id.eq.3), id.in.(1,4), or(id.eq.1, id.eq.4) )&select=id" `shouldRespondWith`
            [json|[{"id":1}]|] { matchHeaders = [matchContentTypeJson] }

    context "used with POST" $
      it "includes related data with filters" $
        request methodPost "/child_entities?entities.or=(id.eq.2,id.eq.3)&select=id,entities{id}"
          [("Prefer", "return=representation")]
          [json|[{"id":4,"name":"entity 4","parent_id":1},
                 {"id":5,"name":"entity 5","parent_id":2},
                 {"id":6,"name":"entity 6","parent_id":3}]|] `shouldRespondWith`
          [json|[{"id": 4, "entities":null}, {"id": 5, "entities": {"id": 2}}, {"id": 6, "entities": {"id": 3}}]|]
          { matchStatus = 201, matchHeaders = [matchContentTypeJson] }

    context "used with PATCH" $
      it "succeeds when using and/or params" $
        request methodPatch "/grandchild_entities?or=(id.eq.1,id.eq.2)&select=id,name"
          [("Prefer", "return=representation")]
          [json|{ name : "updated grandchild entity"}|] `shouldRespondWith`
          [json|[{ "id": 1, "name" : "updated grandchild entity"},{ "id": 2, "name" : "updated grandchild entity"}]|]
          { matchHeaders = [matchContentTypeJson] }

    context "used with DELETE" $
      it "succeeds when using and/or params" $
        request methodDelete "/grandchild_entities?or=(id.eq.1,id.eq.2)&select=id,name"
          [("Prefer", "return=representation")] "" `shouldRespondWith`
          [json|[{ "id": 1, "name" : "updated grandchild entity"},{ "id": 2, "name" : "updated grandchild entity"}]|]
          { matchHeaders = [matchContentTypeJson] }

    it "can query columns that begin with and/or reserved words" $
      get "/grandchild_entities?or=(and_starting_col.eq.smth, or_starting_col.eq.smth)" `shouldRespondWith` 200

    it "can query jsonb columns" $
      get "/grandchild_entities?or=(jsonb_col->a->>b.eq.foo, jsonb_col->>b.eq.bar)&select=id" `shouldRespondWith`
        [json|[{id: 4}, {id: 5}]|] { matchStatus = 200, matchHeaders = [matchContentTypeJson] }

    it "fails when using IN without () and provides meaningful error message" $
      get "/entities?or=(id.in.1,2,id.eq.3)" `shouldRespondWith`
        [json|{
          "details": "unexpected \"1\" expecting \"(\"",
          "message": "\"failed to parse logic tree ((id.in.1,2,id.eq.3))\" (line 1, column 10)"
        }|] { matchStatus = 400, matchHeaders = [matchContentTypeJson] }

    it "fails on malformed query params and provides meaningful error message" $ do
      get "/entities?or=)(" `shouldRespondWith`
        [json|{
          "details": "unexpected \")\" expecting \"(\"",
          "message": "\"failed to parse logic tree ()()\" (line 1, column 3)"
        }|] { matchStatus = 400, matchHeaders = [matchContentTypeJson] }
      get "/entities?and=(ord(id.eq.1,id.eq.1),id.eq.2)" `shouldRespondWith`
        [json|{
          "details": "unexpected \"d\" expecting \"(\"",
          "message": "\"failed to parse logic tree ((ord(id.eq.1,id.eq.1),id.eq.2))\" (line 1, column 7)"
        }|] { matchStatus = 400, matchHeaders = [matchContentTypeJson] }
      get "/entities?or=(id.eq.1,not.xor(id.eq.2,id.eq.3))" `shouldRespondWith`
        [json|{
          "details": "unexpected \"x\" expecting logic operator (and, or)",
          "message": "\"failed to parse logic tree ((id.eq.1,not.xor(id.eq.2,id.eq.3)))\" (line 1, column 16)"
        }|] { matchStatus = 400, matchHeaders = [matchContentTypeJson] }
