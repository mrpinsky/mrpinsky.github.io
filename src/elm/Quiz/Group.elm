module Quiz.Group
    exposing
        ( Group
        , Msg
        , init
        , reset
        , update
        , view
        , encode
        , decoder
        )

import Css
import Dict exposing (Dict)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events as Events exposing (..)
import Html.Lazy exposing (..)
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import KeyedList exposing (KeyedList, Key)
import Quiz.Observation as Observation exposing (Observation)
import Quiz.Observation.Record as Record exposing (Record)
import Quiz.Settings as Settings exposing (..)
import Quiz.Theme as Theme exposing (Theme)
import Util exposing (..)


-- MODEL


type alias Group =
    { current : Maybe Theme.Id
    , id : Int
    , label : String
    , records : KeyedList Record
    , defaults : Dict String Int
    }


init : Int -> String -> Group
init id label =
    Group Nothing id label KeyedList.empty Dict.empty


reset : Group -> Group
reset group =
    { group
        | current = Nothing
        , records = KeyedList.empty
        , defaults = Dict.empty
    }



-- UPDATE


type Msg
    = StartNew Theme.Id
    | CommitCurrent Theme.Id String
    | CancelCurrent
    | IncrementDefault String
    | UpdateRecord Key Record.Msg
    | Delete Key
    | Relabel String


update : Msg -> Group -> Group
update msg group =
    case msg of
        StartNew topicId ->
            { group | current = Just topicId }

        CommitCurrent style label ->
            { group
                | current = Nothing
                , records = commit group.records style label
            }

        CancelCurrent ->
            { group | current = Nothing }

        IncrementDefault defaultId ->
            { group | defaults = Dict.update defaultId incrementDefault group.defaults }

        UpdateRecord key submsg ->
            { group
                | records =
                    KeyedList.update key
                        (Record.update submsg)
                        group.records
            }

        Delete key ->
            { group | records = KeyedList.remove key group.records }

        Relabel newLabel ->
            { group | label = newLabel }


incrementDefault : Maybe Int -> Maybe Int
incrementDefault tally =
    tally
        |> Maybe.withDefault 0
        |> (+) 1
        |> Just


commit : KeyedList Record -> Theme.Id -> String -> KeyedList Record
commit existing style label =
    if String.isEmpty label then
        existing
    else
        let
            new =
                Record.init 1 <| Observation style label
        in
            KeyedList.cons new existing



-- VIEW


view : Handlers Msg msg { highlightMsg : msg } -> Settings -> Group -> Html msg
view handlers { theme, observations, showTally } group =
    div
        [ class "group"
        , id <| "group-" ++ toString group.id
        ]
        [ lazy2 viewLabel handlers group.label
        , button [ class "highlight-button unobtrusive float-left", onClick handlers.highlightMsg ] [ text "H" ]
        , button [ class "remove unobtrusive float-right", onClick handlers.remove ] [ text "x" ]
        , Html.map handlers.onUpdate <|
            div [ class "body" ]
                [ lazy3 viewDefaults theme observations group.defaults
                , lazy2 viewRecords theme group.records
                ]
        , lazy3 viewDrawer handlers theme group.current
        ]



-- viewAsHighlight : Handlers Msg msg r -> Settings -> Group -> Html msg
-- viewAsHighlight handlers { theme, observations, showTally } group =
--     div
--         [ class "group" ]
--         [ lazy2 viewLabel handlers group.label
--         , Html.map handlers.onUpdate <|
--             div [ class "body" ]
--                 [ lazy3 viewDefaults theme observations group.defaults
--                 , lazy2 viewRecords theme group.records
--                 ]
--         ]


viewLabel : Handlers Msg msg r -> String -> Html msg
viewLabel { onUpdate, remove } label =
    div [ class "title" ]
        [ input
            [ onInput (onUpdate << Relabel)
            , value label
            ]
            []
        ]


viewTally : Theme -> Bool -> KeyedList Record -> Html Msg
viewTally theme showTally records =
    let
        total =
            KeyedList.toList records
                |> List.map (Record.value theme)
                |> List.sum
    in
        total
            |> toString
            |> text
            |> List.singleton
            |> h2
                [ classList
                    [ ( "points", True )
                    , ( "hidden", not showTally )
                    , ( "total-" ++ (toString <| clamp 0 10 <| abs total), True )
                    , ( "pos", total > 0 )
                    ]
                ]


viewDrawer : Handlers Msg msg r -> Theme -> Maybe Theme.Id -> Html msg
viewDrawer { onUpdate } theme current =
    let
        contents =
            case current of
                Nothing ->
                    Theme.viewAsButtons StartNew current theme

                Just id ->
                    viewInput theme id
    in
        div
            [ class "drawer"
            , classList [ ( "open", current /= Nothing ) ]
            ]
            [ Html.map onUpdate contents ]


viewInput : Theme -> Theme.Id -> Html Msg
viewInput theme id =
    let
        { symbol, color } =
            Theme.lookup id theme
    in
        div
            [ class "input-container"
            , styles [ Css.backgroundColor <| faded color ]
            ]
            [ div
                [ class "symbol"
                , styles [ Css.backgroundColor color ]
                ]
                [ text symbol ]
            , textarea
                [ onEnter <| CommitCurrent id
                , class "observation creating"
                , value ""
                ]
                []
            , button
                [ class "cancel"
                , onClick CancelCurrent
                ]
                [ text "x" ]
            ]


viewDefaults : Theme -> List ( String, Observation ) -> Dict String Int -> Html Msg
viewDefaults theme defaults tallies =
    List.map (viewDefaultObservation theme tallies) defaults
        |> ul [ class "observations default" ]


viewDefaultObservation : Theme -> Dict String Int -> ( String, Observation ) -> Html Msg
viewDefaultObservation theme tallies ( id, observation ) =
    let
        tally =
            Dict.get id tallies
                |> Maybe.withDefault 0

        { color, symbol } =
            Theme.lookup observation.style theme

        tallyBgColor =
            if tally == 0 then
                Css.hex "eeeeee"
            else
                color
    in
        li
            [ styles [ Css.backgroundColor <| fade color tally ]
            , class "observation default"
            ]
            [ div
                [ class "buttons start"
                , styles [ Css.backgroundColor tallyBgColor ]
                ]
                [ button
                    [ onClick (IncrementDefault id)
                    , class "tally"
                    ]
                    [ Html.text <| toString tally ++ symbol ]
                ]
            , span
                [ class "label" ]
                [ Html.text observation.label ]
            ]


viewRecords : Theme -> KeyedList Record -> Html Msg
viewRecords theme records =
    viewLocals theme records
        |> ul [ class "observations local" ]


viewLocals : Theme -> KeyedList Record -> List (Html Msg)
viewLocals theme records =
    KeyedList.keyedMap (viewKeyedRecord theme) records


viewKeyedRecord : Theme -> Key -> Record -> Html Msg
viewKeyedRecord theme key record =
    Record.view
        { onUpdate = UpdateRecord key
        , remove = Delete key
        }
        theme
        record



-- JSON


encode : Group -> Encode.Value
encode { id, label, records, defaults } =
    Encode.object
        [ "id" => Encode.int id
        , "label" => Encode.string label
        , "records" => encodeRecords records
        , "defaults" => encodeDefaults defaults
        ]


encodeRecords : KeyedList Record -> Encode.Value
encodeRecords records =
    records
        |> KeyedList.toList
        |> List.map Record.encode
        |> Encode.list


encodeDefaults : Dict String Int -> Encode.Value
encodeDefaults defaults =
    defaults
        |> Dict.toList
        |> List.map (Tuple.mapSecond Encode.int)
        |> Encode.object


decoder : Decoder Group
decoder =
    Decode.map4 (Group Nothing)
        (Decode.field "id" Decode.int)
        (Decode.field "label" Decode.string)
        (Decode.field "records" recordsDecoder)
        (Decode.field "defaults" defaultsDecoder)


recordsDecoder : Decoder (KeyedList Record)
recordsDecoder =
    Decode.list Record.decoder
        |> Decode.map (KeyedList.fromList)


defaultsDecoder : Decoder (Dict String Int)
defaultsDecoder =
    Decode.dict Decode.int
