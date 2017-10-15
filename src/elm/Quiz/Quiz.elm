module Quiz.Quiz exposing (Quiz, Msg, init, update, view, encode, decoder, default)

-- Elm Packages

import Css
import Html exposing (..)
import Html.Attributes exposing (class)
import Html.Events exposing (..)
import Html.Lazy exposing (..)
import Json.Encode as Encode
import Json.Decode as Decode
import KeyedList exposing (KeyedList, Key)
import Quiz.Group as Group exposing (Group)
import Quiz.Observation as Observation exposing (Observation)
import Quiz.Settings as Settings exposing (Settings)
import Util exposing ((=>), keyedListDecoder, encodeKeyedList, styles, viewWithRemoveButton)


-- MODEL


type Quiz
    = Quiz String (KeyedList Group)


encode : Quiz -> Encode.Value
encode (Quiz title groups) =
    Encode.object
        [ "title" => Encode.string title
        , "groups" => encodeKeyedList Group.encode groups
        ]


decoder : Decode.Decoder Quiz
decoder =
    Decode.map2
        Quiz
        (Decode.field "title" Decode.string)
        -- (Decode.field "settings" Settings.decoder)
        (Decode.field "groups" <| keyedListDecoder Group.decoder)


default : Quiz
default =
    blankGroups 8
        |> Quiz "Unnamed Quiz"


blankGroups : Int -> KeyedList Group
blankGroups count =
    withGroups count []


withGroups : Int -> List Observation -> KeyedList Group
withGroups count observations =
    List.range 1 count
        |> List.map (numberedGroup observations)
        |> KeyedList.fromList


numberedGroup : List Observation -> Int -> Group
numberedGroup observations n =
    Group.init ("Group " ++ toString n) observations


init : String -> List Observation -> Quiz
init title observations =
    observations
        |> withGroups 8
        |> Quiz title



-- MESSAGING


type Msg
    = Rename String
    | AddGroup String
    | UpdateGroup Key Group.Msg
    | RemoveGroup Key
    | ResetGroups



-- UPDATE


update : Msg -> Quiz -> Quiz
update msg (Quiz title groups) =
    case msg of
        Rename newTitle ->
            Quiz newTitle groups

        AddGroup groupName ->
            let
                newGroups =
                    KeyedList.push (Group.init groupName []) groups
            in
                Quiz title newGroups

        UpdateGroup key submsg ->
            let
                newGroups =
                    KeyedList.update key (Group.update submsg) groups
            in
                Quiz title newGroups

        RemoveGroup key ->
            let
                newGroups =
                    KeyedList.remove key groups
            in
                Quiz title newGroups

        ResetGroups ->
            let
                newGroups =
                    KeyedList.length groups
                        |> blankGroups
            in
                Quiz title newGroups



-- VIEW


view : Settings -> Quiz -> Html Msg
view settings (Quiz title groups) =
    div []
        [ lazy viewTitle title
        , lazy viewMenu settings
        , div [ styles [ Css.displayFlex ] ] <|
            KeyedList.keyedMap (lazy3 viewKeyedGroup settings) groups
        ]


viewTitle : String -> Html Msg
viewTitle title =
    h1 [] [ text title ]


viewMenu : Settings -> Html Msg
viewMenu settings =
    div []
        [ menuButton (AddGroup "New Group") "Add Group"
        , menuButton ResetGroups "Reset All Groups"

        -- , menuButton (SetTallyDisplays True) "Show Point Tallies"
        -- , menuButton (SetTallyDisplays False) "Hide Point Tallies"
        -- , List.range 2 5
        --     |> List.map numAcrossButton
        --     |> List.append [ text "Groups per Row: " ]
        --     |> span []
        ]


styledButton : String -> Msg -> String -> Html Msg
styledButton className msg label =
    button
        [ onClick msg
        , class className
        ]
        [ text label ]


menuButton : Msg -> String -> Html Msg
menuButton msg label =
    styledButton "menu-button" msg label


viewKeyedGroup : Settings -> Key -> Group -> Html Msg
viewKeyedGroup settings key group =
    Group.view settings group
        |> Html.map (UpdateGroup key)
        |> viewWithRemoveButton (RemoveGroup key)
