xquery version "1.0";

(:
 : Module Name: MODS to DC
 : Module Version: 1.0
 : Date: September, 2007
 : Copyright: Michael J. Giarlo and Winona Salesky
 : XQuery Specification: November 2005
 : Module Overview: extracts Dublin Core elements from MODS records
 :)

(:~
 : Extracts Dublin Core elements from MODS records 
 :
 : @author Michael J. Giarlo
 : @author Winona Salesky
 : @since September, 2007
 : @version 1.0
 :)

module namespace mods-to-dc = 'http://diglib.princeton.edu/ns/xquery/mods-to-dc';

declare default function namespace 'http://diglib.princeton.edu/ns/xquery/mods-to-dc';

declare namespace mods  = 'http://www.loc.gov/mods/v3';
declare namespace dc    = 'http://purl.org/dc/elements/1.1/';

(:~
 : Get titles from MODS record and wrap them in Dublin Core
 :
 : @param $_record a MODS XML doc
 : @return Dublin Core XML 
 :)
declare function get-title($_record) {
    for $titleInfo in $_record/mods:titleInfo
    let $title     := $titleInfo/mods:title
    let $subtitles := if (fn:empty($titleInfo/mods:subTitle)) then () 
                      else 
                          for $subtitle in $titleInfo/mods:subTitle 
                          return fn:string($subtitle)
    return
        <dc:title>{ fn:string-join((fn:string($title), $subtitles), " : ") }</dc:title>
};

(:~
 : Get descriptions from MODS record and wrap it in Dublin Core
 :
 : @param $_record a MODS XML doc
 : @return Dublin Core XML 
 :)
declare function get-description($_record) {
    for $description in $_record//mods:note/descendant-or-self::*/text() | $_record//mods:abstract/descendant-or-self::*/text()
    return
        <dc:description>{ $description }</dc:description>
};

(:~
 : Get dates from MODS record and wrap it in Dublin Core
 :
 : @param $_record a MODS XML doc
 : @return Dublin Core XML 
 :)
declare function get-date($_record) {
    for $date in $_record//mods:date  | $_record//mods:dateCreated | $_record//mods:dateIssued
    return
        <dc:date>{ fn:string($date) }</dc:date>
};

(:~
 : Get identifiers from MODS record and wrap it in Dublin Core
 :
 : @param $_record a MODS XML doc
 : @return Dublin Core XML 
 :)
declare function get-identifier($_record) {
    for $identifier in $_record/mods:identifier/text()
    return
        <dc:identifier>{ $identifier }</dc:identifier>
};

(:~
 : Get relations from MODS record and wrap it in Dublin Core
 :
 : @param $_record a MODS XML doc
 : @return Dublin Core XML 
 :)
declare function get-relation($_record) {
    for $relatedItem in $_record/mods:relatedItem[fn:exists(child::mods:identifier)]
    let $relation   := fn:string($relatedItem/@type)
    let $identifier := $relatedItem/mods:identifier/text()
    return
        <dc:relation>{ fn:concat($relation, " of ", $identifier) }</dc:relation>
};

(:~
 : Get creators from MODS record and wrap it in Dublin Core
 :
 : @param $_record a MODS XML doc
 : @return Dublin Core XML 
 :)
declare function get-creator($_record) {
    if (fn:exists($_record//mods:name[mods:role/mods:roleTerm/text()='creator' or mods:role/mods:roleTerm/text()='photographer'])) then
	    for $creator in get-names($_record//mods:name[mods:role/mods:roleTerm/text()='creator' or mods:role/mods:roleTerm/text()='photographer'])
        return
            <dc:creator>{ fn:string($creator) }</dc:creator>
    else 
        ()
};

(:~
 : Get contributors from MODS record and wrap it in Dublin Core
 :
 : @param $_record a MODS XML doc
 : @return Dublin Core XML 
 :)
declare function get-contributor($_record) {
    for $contributor in get-names($_record//mods:name[mods:role/mods:roleTerm/text()='contributor'])
    return
        <dc:contributor>{ fn:string($contributor) }</dc:contributor>
};

(:~
 : Get subjects from MODS record and wrap it in Dublin Core
 :
 : @param $_record a MODS XML doc
 : @return Dublin Core XML 
 :)
declare function get-subject($_record) {
    let $subjects         := $_record//mods:subject/descendant::*[fn:local-name() != 'namePart']/text() | $_record//mods:genre/descendant-or-self::*/text()   
    let $names            := $_record//mods:subject/mods:name
    let $subjectsWithName := fn:insert-before($subjects, 1, get-names($names))
    for $subject in fn:distinct-values($subjectsWithName)
    return
        <dc:subject>{ fn:string($subject) }</dc:subject>
};

(:~
 : Extract names from any MODS element (a helper function)
 :
 : @param $_record a sequence of mods:name elements
 : @return string representing a composed name
 :)
declare function get-names($_names) {
    for $name in $_names
    let $nameParts := $name/mods:namePart/text()
    let $dcName    := fn:string-join($nameParts, ", ")
    return $dcName
};