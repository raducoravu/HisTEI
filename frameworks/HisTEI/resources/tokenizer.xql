xquery version "3.0";

import module namespace functx="http://www.functx.com" at "functx.xql";
import module namespace teix="http://cohd.info/xquery/tei" at "tei.xqm";
import module namespace utils="http://histei.info/xquery/utils" at "utils.xqm";

declare default element namespace "http://www.tei-c.org/ns/1.0";

declare namespace map="http://www.w3.org/2005/xpath-functions/map";

declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:omit-xml-declaration "no";
declare option output:indent "no";

declare variable $userID as xs:string external := "";

(: Tokenization Regex Character Classes - can also be passed in externally :)
declare variable $numberBreakClass as xs:string external := ":\.\-/'""%";
declare variable $numberClass as xs:string external := "\p{N}";
declare variable $nonBreakingPunctClass as xs:string external := "\p{Pd}\p{Pc}'=";
declare variable $breakingPunctClass as xs:string external := "\p{S}\p{P}";
declare variable $whitespaceClass as xs:string external := "\s";
declare variable $wordClass as xs:string external := "\p{L}\p{M}";

(: TEI-specific element names and their use in our corpus:)
declare variable $contentNames := ("p", "head", "dateline", "signed", "salute", 
                                    "byline", "argument", "epigraph", "trailer", "address");
declare variable $breakNames := ( "cb", "gb", "lb", "milestone", "pb");
declare variable $milestoneNames := ($breakNames, "handShift");
declare variable $subWordToSplitNames := ("expan", "supplied", "unclear");
declare variable $subWordNeverTokenizedNames := ("abbr");
declare variable $subWordNames := ($subWordToSplitNames, $subWordNeverTokenizedNames, "gap");
declare variable $annotationNames := ("w", "pc", "num");
declare variable $editNames := ("add", "del", "hi");


declare variable $TYPE_LABEL := "type";
declare variable $REGEX_LABEL := "regex";
declare variable $IS_BREAK_LABEL := "isBreak";
declare variable $ANN_FUNC_LABEL := "annFunc";
declare variable $defaultTokenTypes := local:token-types();

declare function local:token-types() as map(xs:integer, map(xs:string, item())) {
    let $numberClassRegex := concat("[", $numberClass, "]")
    let $numberBreakClassRegex := concat("[", $numberBreakClass, "]")
    let $wordClassRegex := concat("[", $wordClass, "]")
    let $nonBreakingPunctClassRegex := concat("[", $nonBreakingPunctClass, "]")
    
    let $ordinalNumberRegex := concat($numberClassRegex, "+", $wordClassRegex, "+")
    
    let $numberRegex := concat($numberClassRegex, "+[", $numberBreakClass, $numberClass, "]*|", 
        "[", $numberClass, $numberBreakClass, "]*", $numberClassRegex, "+", $numberBreakClassRegex, "*")
    
    let $compoundRegex := concat($wordClassRegex, "+", $nonBreakingPunctClassRegex, "+[", $wordClass, $nonBreakingPunctClass, "]*|", 
        "[", $wordClass, $nonBreakingPunctClass, "]*", $nonBreakingPunctClassRegex, "+", $wordClassRegex, "+")
        
    let $breakingPunctRegex := concat("\.\.\.|[", $breakingPunctClass, "]")
    
    let $whitespaceRegex := concat("[", $whitespaceClass, "]+")
    
    let $wordRegex := concat($wordClassRegex, "+")
    return
        map {
            1 := map { $TYPE_LABEL := "ordinal", $REGEX_LABEL := $ordinalNumberRegex, $ANN_FUNC_LABEL := teix:num(?, "ordinal") },
            2 := map { $TYPE_LABEL := "number", $REGEX_LABEL := $numberRegex, $ANN_FUNC_LABEL := local:num#1 },
            3 := map { $TYPE_LABEL := "compound", $REGEX_LABEL := $compoundRegex, $ANN_FUNC_LABEL := teix:word#1 },
            4 := map { $TYPE_LABEL := "breakingPunct", $REGEX_LABEL := $breakingPunctRegex, $IS_BREAK_LABEL := true(), $ANN_FUNC_LABEL := teix:pc#1 },
            5 := map { $TYPE_LABEL := "whitespace", $REGEX_LABEL := $whitespaceRegex, $IS_BREAK_LABEL := true() },
            6 := map { $TYPE_LABEL := "word", $REGEX_LABEL := $wordRegex, $ANN_FUNC_LABEL := teix:word#1 },
        }
};

declare function local:token-type-name($tokenTypes as map(xs:integer, map(xs:string, item())), 
                                            $tokenKey as xs:integer?) as xs:string? {
    let $tokenType := $tokenTypes($tokenKey)
    return
        if (exists($tokenType)) then 
            $tokenType($TYPE_LABEL) 
        else 
            ()
};

declare function local:regex($tokenTypes as map(xs:integer, map(xs:string, item())), 
                                $tokenKey as xs:integer?) as xs:string? {
    let $tokenType := $tokenTypes($tokenKey)
    return
        if (exists($tokenType)) then 
            $tokenType($REGEX_LABEL) 
        else 
            ()
};

declare function local:ann-func($tokenTypes as map(xs:integer, map(xs:string, item())), 
                                    $tokenKey as xs:integer?) as (function(item()*) as element()*)? {
    let $tokenType := $tokenTypes($tokenKey)
    return
        if (exists($tokenType)) then 
            $tokenType($ANN_FUNC_LABEL) 
        else 
            ()
};

declare function local:run-ann-func($tokenTypes as map(xs:integer, map(xs:string, item())), 
                                    $tokenKey as xs:integer?, $content) {
    let $annFunc := local:ann-func($tokenTypes, $tokenKey)
    return
        if (exists($annFunc)) then 
            $annFunc($content) 
        else 
            $content
};

declare function local:is-break($tokenTypes as map(xs:integer, map(xs:string, item())), 
                                    $tokenKey as xs:integer?) as xs:boolean {
    let $tokenType := $tokenTypes($tokenKey)
    return
        if (exists($tokenType) and exists($tokenType($IS_BREAK_LABEL))) then 
            $tokenType($IS_BREAK_LABEL) 
        else 
            false()
};

declare function local:num($content) as element(num)? {
    if (empty($content)) then
        ()
    else
        let $numberClassRegex := concat("[", $numberClass, "]")
        let $numTypes := map { 
            "ordinal" := $defaultTokenTypes(1)($REGEX_LABEL), 
            "fraction" := concat($numberClassRegex, "+/", $numberClassRegex, "+"), 
            "percentage" := concat($numberClassRegex, "+%"),
            "decimal" := concat($numberClassRegex, "+([,:\.]", $numberClassRegex, "+)+"),
            "cardinal" := concat("^", $numberClassRegex, "+[\.]*$")
        }
        let $num := element num { $content }
        let $text := string($num)
        let $type := 
            for $key in map:keys($numTypes)
            return
                if (matches($text, $numTypes($key))) then
                    $key
                else
                    ()
        return
            teix:num($content, $type)
};

declare function local:trimTextNode($textNode as text()?) as text()? {
    if (exists($textNode)) then
        if (utils:is-empty-oxy-comment($textNode)) then
            $textNode
        else
            let $preceding := $textNode/preceding::node()[self::* or (self::text() and not(utils:is-empty-oxy-comment(.)))][1]
            let $isBegin := (local-name($preceding) = $breakNames)
                    
            let $following := $textNode/following::node()[self::* or (self::text() and not(utils:is-empty-oxy-comment(.)))][1]
            let $isEnd := (local-name($following) = $breakNames)
            
            let $text := 
                if ($isBegin and $isEnd) then
                    normalize-space($textNode)
                else
                    let $str := replace($textNode, "\s+", " ")
                    return
                        if ($isBegin) then
                            functx:left-trim($str)
                        else if ($isEnd) then
                            functx:right-trim($str)
                        else
                            $str
            return
                if ($text eq "") then () else text { $text }
    else
        ()
};

declare function local:clean-spaces($element as element()) {
    let $trimmedElement := utils:replace-content($element,
        for $node in $element/node()
        return
            typeswitch ($node)
            case text() return
                local:trimTextNode($node)
            case element() return
                local:clean-spaces($node)
            default return
                $node
    ) 

    let $firstChild := $trimmedElement/(text()[not(utils:is-empty-oxy-comment(.))] | *)[1]
    let $lastChild := $trimmedElement/(text()[not(utils:is-empty-oxy-comment(.))] | *)[last()]
    
    return
        if (empty($firstChild)) then
            $trimmedElement
        else
            let $addBeginSpace := 
                if ($firstChild instance of text()) then 
                    utils:contains-ws(local:trimTextNode($firstChild), "starts") 
                else 
                    false()
            
            let $addEndSpace := 
                if ($lastChild instance of text()) then 
                    utils:contains-ws(local:trimTextNode($lastChild), "ends") 
                else 
                    false()
            
            let $childNodes :=
                for $node in $trimmedElement/node()
                return
                    typeswitch ($node)
                    case text() return
                        let $trimmedText := local:trimTextNode($node)
                        return
                            if ($firstChild is $lastChild) then
                                if ($node is $firstChild) then 
                                    text { normalize-space($trimmedText) }
                                else
                                    $trimmedText
                            else
                                if ($addBeginSpace and $node is $firstChild) then
                                    text { functx:left-trim($trimmedText) }
                                else if ($addEndSpace and $node is $lastChild) then
                                    text { functx:right-trim($trimmedText) }
                                else
                                    $trimmedText
                    default return
                        $node
            
            let $textSpace := text { " " }
            return
            (
                if ($addBeginSpace) then $textSpace else (),
                utils:replace-content($trimmedElement, $childNodes),
                if ($addEndSpace) then $textSpace else ()
            )
};

declare function local:clean-spaces-doc($element as element()) as element() {
    utils:replace-content($element, 
        for $node in $element/node()
        return
            typeswitch($node)
            case element() return
                if (local-name($node) = $contentNames) then
                    local:clean-spaces($node)
                else
                    local:clean-spaces-doc($node)
            default return
                $node
    )
};

declare function local:sub-word-elements-token-types($annFunc as function(item()*) as element()*) 
                                                        as map(xs:integer, map(xs:string, item())) {
    map:new(
        for $key in map:keys($defaultTokenTypes)
        let $typeName := local:token-type-name($defaultTokenTypes, $key)
        let $tokenMap := $defaultTokenTypes($key)
        return
            map:entry(
                $key, 
                if ($typeName = ("ordinal", "number", "compound", "word")) then 
                    map:new(($tokenMap, map { $ANN_FUNC_LABEL := $annFunc }))
                else
                    map:remove($tokenMap, $ANN_FUNC_LABEL)
            )
    )
};

declare function local:split-sub-word-elements-doc($element as element()) as element() {
    utils:replace-content($element, 
        for $node in $element/node()
        return
            typeswitch($node)
            case element() return
                let $elementName := local-name($node)
                return
                    if ($elementName = $subWordToSplitNames) then
                        let $annFunc := function($content) { utils:replace-content($node, $content) }
                        let $tokenTypes := local:sub-word-elements-token-types($annFunc)
                        return
                            local:tokenize($tokenTypes, $node/node())
                    else
                        local:split-sub-word-elements-doc($node)
            default return
                $node
    )
};

declare function local:token($tokenTypes as map(xs:integer, map(xs:string, item())), $content) {
    if (empty($content)) then
        $content
    else 
        let $key := 
            let $token := element w { $content }
            let $token := xs:string($token)
            let $tokenSplit := local:split-text($tokenTypes, $token)
            return
                if (count($tokenSplit) eq 1) then
                    map:keys($tokenSplit)[1]
                else
                    (: If there are multiple tokens, then just use default annFunc for 'word' token type :)
                    6
        return
            if (count($content) gt 1) then
                local:run-ann-func($tokenTypes, $key, $content)
            else
                typeswitch($content)
                case element() return
                    let $elementName := local-name($content)
                    return
                        if ($elementName = ($milestoneNames, "gap")) then
                            $content
                        else if (exists($elementName) and not($elementName = $subWordNames)) then
                            utils:replace-content($content, local:tokenize($tokenTypes, $content/node()))
                        else
                            local:run-ann-func($tokenTypes, $key, $content)
                
                case comment() return $content
                case processing-instruction() return $content
                default return
                    local:run-ann-func($tokenTypes, $key, $content)
};

declare function local:compound($compound as xs:string?) {
    if (empty($compound)) then
        $compound
    else
        let $split := analyze-string($compound, concat("[", $nonBreakingPunctClass, "]"))
        for $part in $split/*
        return
            typeswitch($part)
            case element(fn:match) return
                teix:pc($part/text(), "weak")
            case element(fn:non-match) return
                $part/text()
            default return
                ()
};

declare function local:split-text($tokenTypes as map(xs:integer, map(xs:string, item())), 
                                        $text as xs:string) as map(xs:integer, item()*)* {
    let $regexes := 
        for $key in map:keys($tokenTypes)
        let $tokenType := $tokenTypes($key)
        order by $key
        return
            concat("(", $tokenType($REGEX_LABEL), ")")
                
    let $regex := string-join($regexes, "|")
    let $tokens := analyze-string($text, $regex)
    return
    (
        for $token in $tokens/*
        return
            typeswitch($token)
            case element(fn:match) return
                let $key := xs:integer($token/fn:group/@nr)
                let $text := xs:string($token/fn:group/text())
                let $typeName := local:token-type-name($tokenTypes, $key)
                let $text := if ("compound" eq $typeName) then local:compound($text) else $text
                return
                    map{ $key := $text }
            case element(fn:non-match) return
                map{ 0 := xs:string($token/text()) }
            default return
                ()
    )
};

declare function local:tokenize-text($text as text(), $tokenTypes as map(xs:integer, map(xs:string, item())), 
                                        $nodes as node()*, $nextN as xs:integer?, $currentToken) {
    let $tokens := local:split-text($tokenTypes, $text)
    let $numTokens := count($tokens)
    return
        let $tokenized := 
            for $tokenMap at $i in $tokens
            let $key := map:keys($tokenMap)[1]
            let $token := $tokenMap($key)
            let $isBreak := local:is-break($tokenTypes, $key)
            return
                if ($i eq 1 and exists($currentToken)) then
                    if ($isBreak) then
                        ( local:token($tokenTypes, $currentToken), local:run-ann-func($tokenTypes, $key, $token) )
                    else
                        if ($numTokens gt 1) then
                            local:token($tokenTypes, ($currentToken, $token))
                        else
                            ()
                else if ($i eq $numTokens and not($isBreak)) then
                    ()
                else
                    local:run-ann-func($tokenTypes, $key, $token)
                
        let $lastToken := 
            let $lastTokenMap := $tokens[last()]
            let $key := map:keys($lastTokenMap)[1]
            let $isBreak := local:is-break($tokenTypes, $key)
            return
                if ($isBreak) then 
                    () 
                else
                    let $token := $lastTokenMap($key)
                    return
                        if ($numTokens eq 1) then
                            ( $currentToken, $token )
                        else
                            $token
                    
        return
            ( $tokenized, local:tokenize($tokenTypes, $nodes, $nextN, $lastToken) )
};

declare function local:tokenize-element($element as element(), $tokenTypes as map(xs:integer, map(xs:string, item())),
                                            $nodes as node()*, $nextN as xs:integer?, $currentToken) {
    let $elementName := local-name($element)
    return
        if ($elementName = $subWordNeverTokenizedNames) then
            ( local:token($tokenTypes, $currentToken), local:token($tokenTypes, $element), local:tokenize($tokenTypes, $nodes, $nextN) )
        else if ($elementName = ($breakNames, $annotationNames)) then
            if ($element/@break eq "no" or $element/@force eq "weak") then
                local:tokenize($tokenTypes, $nodes, $nextN, ($currentToken, $element))
            else
                ( local:token($tokenTypes, $currentToken), $element, local:tokenize($tokenTypes, $nodes, $nextN) )
        else if (count(local:split-text($tokenTypes, xs:string($element))) gt 1 
            or not($elementName = ($subWordNames, $editNames, $milestoneNames))) then
        ( 
            local:token($tokenTypes, $currentToken), 
            utils:replace-content($element, local:tokenize($tokenTypes, $element/node())), 
            local:tokenize($tokenTypes, $nodes, $nextN) 
        )
        else
            local:tokenize($tokenTypes, $nodes, $nextN, ($currentToken, $element))
};                                        

declare function local:tokenize($tokenTypes as map(xs:integer, map(xs:string, item())), 
                                    $nodes as node()*, $n as xs:integer?, $currentToken) {
    if (empty($nodes)) then
        $nodes
    else
        let $n := if (empty($n) or $n < 1) then 1 else $n
        let $numNodes := count($nodes)
        let $nextN := $n + 1
        return
            if ($n <= $numNodes) then
                let $node := $nodes[$n]
                return
                    typeswitch($node)
                    case text() return
                        local:tokenize-text($node, $tokenTypes, $nodes, $nextN, $currentToken)
                    case element() return
                        local:tokenize-element($node, $tokenTypes, $nodes, $nextN, $currentToken)
                    default return
                        local:tokenize($tokenTypes, $nodes, $nextN, ($currentToken, $node))
            else
                local:token($tokenTypes, $currentToken)
};

declare function local:tokenize($tokenTypes as map(xs:integer, map(xs:string, item())), 
                                    $nodes as node()*, $n as xs:integer?) {
    local:tokenize($tokenTypes, $nodes, $n, ())
};

declare function local:tokenize($tokenTypes as map(xs:integer, map(xs:string, item())), $nodes as node()*) {
    local:tokenize($tokenTypes, $nodes, ())
};

declare function local:tokenize-doc($element as element()) as element() {
    utils:replace-content($element, 
        for $node in $element/node()
        return
            typeswitch($node)
            case element() return
                if (exists($node/ancestor::body) and local-name($node) = $contentNames) then
                    utils:replace-content($node, local:tokenize($defaultTokenTypes, $node/node()))
                else
                    local:tokenize-doc($node)
            default return
                $node
    )
};

declare function local:update-extent($wordCount as xs:integer, $extent as element(extent)?) as element(extent) {
    let $measure := <measure quantity="{$wordCount}" unit="words">{$wordCount} words</measure>
    let $newContents := $extent/node() except $extent/measure[@unit eq "words"]
    return
        if (exists($extent)) then
            utils:replace-content($extent, ($newContents, $measure) )
        else
            element extent { $measure }
};

declare function local:update-header($tei as element(TEI)) as element(TEI) {
    let $wordCount := count($tei//w | $tei//num)
    
    let $teiHeader := $tei/teiHeader[1]
    let $fileDesc := $teiHeader/fileDesc[1]
    let $extent := local:update-extent($wordCount, $fileDesc/extent[1])
    
    let $fileDescContents := $fileDesc/node() except $fileDesc/extent
    let $pubStmtPos := index-of($fileDescContents, ($fileDesc/publicationStmt | $fileDesc/sourceDesc)[1])
    let $fileDescContents := if (exists($pubStmtPos)) then insert-before($fileDescContents, $pubStmtPos, $extent) else ($fileDescContents, $extent)
    let $newFileDesc := utils:replace-content($fileDesc, $fileDescContents )
    
    let $change := teix:change("tokenized", "Tokenized by HisTEI", $userID)
    let $newRevisionDesc := teix:update-revisionDesc($change, $teiHeader/revisionDesc[1])
    let $newContents := $teiHeader/node() except ($teiHeader/fileDesc, $teiHeader/revisionDesc)
    let $newHeader := utils:replace-content($teiHeader, ( $newFileDesc, $newContents, $newRevisionDesc ) )
    return
        utils:replace-content($tei, ( $newHeader, $tei/node() except $tei/teiHeader ))
};

let $trimmedTrans := local:clean-spaces-doc(/TEI)
let $splitTrans := local:split-sub-word-elements-doc($trimmedTrans)
let $tokenized := local:tokenize-doc($splitTrans)
return
    local:update-header($tokenized)




