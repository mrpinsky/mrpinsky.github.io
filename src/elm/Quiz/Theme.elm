module Quiz.Theme
    exposing
        ( Theme
        , Topic
        , Id
        , Msg
        , update
        , viewAsEditable
        , viewAsButtons
        , defaultTopic
        , init
        , default
        , toList
        , idList
        , lookup
        , encode
        , encodeId
        , decoder
        , idDecoder
        )

import Css exposing (Color)
import Css.Colors as Colors
import Html exposing (..)
import Html.Attributes as Attributes exposing (..)
import Html.Events exposing (onClick)
import Json.Decode as Decode
import Json.Encode as Encode
import List.Nonempty as NE exposing (Nonempty, (:::))
import Quiz.Observation.Style as Style exposing (Style)
import Util
    exposing
        ( (=>)
        , encodeColor
        , colorDecoder
        , viewWithRemoveButton
        , checkmark
        , delta
        , styles
        )


-- MODEL


type Theme
    = Theme Int (Nonempty Topic)


type alias Topic =
    { id : String
    , symbol : String
    , label : String
    , color : Css.Color
    , weight : Int
    , textColor : Css.Color
    }


type alias Id =
    String


init : Theme
init =
    initTopic "1"
        |> NE.fromElement
        |> Theme 2


default : Theme
default =
    defaultTopics
        |> NE.fromList
        |> Maybe.withDefault (NE.fromElement <| initTopic "1")
        |> Theme 1


defaultTopics : List Topic
defaultTopics =
    [ { id = "obs"
      , symbol = "+"
      , label = "Plus"
      , color = Colors.green
      , weight = 1
      , textColor = Colors.black
      }
    , { id = "question"
      , symbol = "?"
      , label = "Question"
      , color = Colors.yellow
      , weight = 0
      , textColor = Colors.black
      }
    , { id = "delta"
      , symbol = delta
      , label = "Delta"
      , color = Colors.red
      , weight = -1
      , textColor = Css.hex "ffffff"
      }
    ]


initTopic : String -> Topic
initTopic id =
    { id = id
    , symbol = checkmark
    , label = "Observation Category"
    , color = Colors.green
    , weight = 1
    , textColor = Css.hex "000000"
    }


defaultTopic : Topic
defaultTopic =
    { id = "default"
    , symbol = checkmark
    , label = "+"
    , color = Css.hex "ffffff"
    , weight = 0
    , textColor = Css.hex "000000"
    }


toList : Theme -> List Topic
toList (Theme _ topics) =
    NE.toList topics


idList : Theme -> Nonempty Id
idList (Theme _ topics) =
    NE.map .id topics


lookup : Id -> Theme -> Topic
lookup target (Theme _ topics) =
    let
        lookupHelper { id } =
            id == target
    in
        NE.toList topics
            |> List.filter lookupHelper
            |> List.head
            |> Maybe.withDefault defaultTopic



-- UPDATE


type Msg
    = Add
    | Remove Id
    | UpdateStyle Id Style.Msg


update : Msg -> Theme -> Theme
update msg (Theme nextId topics) =
    case msg of
        Add ->
            toString nextId
                |> initTopic
                |> NE.fromElement
                |> NE.append topics
                |> Theme (nextId + 1)

        Remove id ->
            let
                removeHelper topic =
                    topic.id /= id
            in
                topics
                    |> NE.filter removeHelper (NE.head topics)
                    |> Theme nextId

        UpdateStyle target styleMsg ->
            let
                updateHelper topic =
                    if topic.id == target then
                        Style.update styleMsg topic
                    else
                        topic
            in
                Theme nextId <| NE.map updateHelper topics



-- VIEW


viewAsEditable : Theme -> Html Msg
viewAsEditable (Theme _ topics) =
    div []
        [ topics
            |> NE.toList
            |> List.map viewTopic
            |> ul [ class "topics" ]
        , button [ onClick Add, class "add-button" ] [ text "+" ]
        ]


viewAsButtons : (Id -> msg) -> Theme -> Html msg
viewAsButtons toMsg (Theme _ topics) =
    topics
        |> NE.map (viewButton toMsg)
        |> NE.toList
        |> div [ class "theme buttons" ]


viewButton : (Id -> msg) -> Topic -> Html msg
viewButton toMsg topic =
    Style.viewAsButton [ onClick (toMsg topic.id) ] topic


viewTopic : Topic -> Html Msg
viewTopic topic =
    li [ class "topic editable" ]
        [ Style.view
            { onUpdate = UpdateStyle topic.id
            , remove = Remove topic.id
            }
            topic
        ]



-- JSON


encode : Theme -> Encode.Value
encode (Theme _ topics) =
    topics
        |> NE.map encodeTopic
        |> NE.toList
        |> Encode.list


encodeTopic : Topic -> Encode.Value
encodeTopic topic =
    Encode.object
        [ "id" => encodeId topic.id
        , "symbol" => Encode.string topic.symbol
        , "label" => Encode.string topic.label
        , "color" => encodeColor topic.color
        , "weight" => Encode.int topic.weight
        ]


encodeId : Id -> Encode.Value
encodeId id =
    Encode.string id


decoder : Decode.Decoder Theme
decoder =
    Decode.list topicDecoder
        |> Decode.map NE.fromList
        |> Decode.map (Maybe.map reconstruct)
        |> Decode.map (Maybe.withDefault init)


reconstruct : Nonempty Topic -> Theme
reconstruct topics =
    let
        nextId =
            NE.get -1 topics
                |> .id
                |> String.toInt
                |> Result.toMaybe
                |> Maybe.withDefault (NE.length topics)
    in
        Theme nextId topics


topicDecoder : Decode.Decoder Topic
topicDecoder =
    Decode.map6
        Topic
        (Decode.field "id" idDecoder)
        (Decode.field "symbol" Decode.string)
        (Decode.field "label" Decode.string)
        (Decode.field "color" colorDecoder)
        (Decode.field "weight" Decode.int)
        (Decode.field "textColor" colorDecoder)


idDecoder : Decode.Decoder Id
idDecoder =
    Decode.string
