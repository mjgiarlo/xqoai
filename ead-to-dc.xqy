xquery version "1.0";

(:
 : Module Name: EAD to DC
 : Module Version: 1.0
 : Date: September, 2007
 : Copyright: Michael J. Giarlo
 : XQuery Specification: November 2005
 : Module Overview: extracts Dublin Core elements from EAD records
 :)

(:~
 : Extracts Dublin Core elements from EAD records 
 :
 : @author Michael J. Giarlo
 : @since September, 2007
 : @version 1.0
 :)

module namespace ead-to-dc = 'http://diglib.princeton.edu/ns/xquery/ead-to-dc';

declare default function namespace 'http://diglib.princeton.edu/ns/xquery/ead-to-dc';

declare namespace ead = "http://diglib.princeton.edu/ead/";
declare namespace dc  = 'http://purl.org/dc/elements/1.1/';

(:~
 : Get titles from EAD record and wrap them in Dublin Core
 :
 : @param $_record a EAD XML doc
 : @return Dublin Core XML 
 :)
declare function get-title($_record) {
    let $title := fn:string-join($_record/ead:eadheader/ead:filedesc/ead:titlestmt/ead:titleproper//text(), " ")
    return
        <dc:title>{ $title }</dc:title>
};

(:~
 : Get descriptions from EAD record and wrap it in Dublin Core
 :
 : @param $_record a EAD XML doc
 : @return Dublin Core XML 
 :)
declare function get-description($_record) {
    for $description in $_record/ead:archdesc/ead:did/ead:abstract/text() | $_record/ead:archdesc/ead:did/ead:unitid/text()
    return
        <dc:description>{ $description }</dc:description>
};

(:~
 : Get dates from EAD record and wrap it in Dublin Core
 :
 : @param $_record a EAD XML doc
 : @return Dublin Core XML 
 :)
declare function get-date($_record) {
    for $date in $_record/ead:eadheader/ead:filedesc/ead:publicationstmt/ead:date/@normal
    return
        <dc:date>{ fn:string($date) }</dc:date>
};

(:~
 : Get identifiers from EAD record and wrap it in Dublin Core
 :
 : @param $_record a EAD XML doc
 : @return Dublin Core XML 
 :)
declare function get-identifier($_record) {
    for $identifier in $_record/ead:eadheader/ead:eadid/@urn | $_record/ead:eadheader/ead:eadid/@url
    return
        <dc:identifier>{ fn:string($identifier) }</dc:identifier>
};

(:~
 : Get rights from EAD record and wrap it in Dublin Core
 :
 : @param $_record a EAD XML doc
 : @return Dublin Core XML 
 :)
declare function get-rights($_record) {
    for $rights in $_record/ead:archdesc/ead:descgrp/ead:accessrestrict/ead:p/text() | $_record/ead:archdesc/ead:descgrp/ead:userestrict/ead:p/text()
    return
        <dc:rights>{ $rights }</dc:rights>
};


(:~
 : Get publishers from EAD record and wrap it in Dublin Core
 :
 : @param $_record a EAD XML doc
 : @return Dublin Core XML 
 :)
declare function get-publisher($_record) {
    let $publisher := fn:string-join($_record/ead:archdesc/ead:did/ead:repository//text(), " ")
    return
        <dc:publisher>{ $publisher }</dc:publisher>
};


(:~
 : Get creators from EAD record and wrap it in Dublin Core
 :
 : @param $_record a EAD XML doc
 : @return Dublin Core XML 
 :)
declare function get-creator($_record) {
    for $creator in $_record/ead:archdesc/ead:did/ead:origination/ead:persname/text()    
    return
        <dc:creator>{ $creator }</dc:creator>
};

(:~
 : Get subjects from EAD record and wrap it in Dublin Core
 :
 : @param $_record a EAD XML doc
 : @return Dublin Core XML 
 :)
declare function get-subject($_record) {
    let $subjectParent := $_record/ead:archdesc/ead:controlaccess
    for $subject in $subjectParent/ead:persname/text() | $subjectParent/ead:corpname/text() |
            $subjectParent/ead:title/text() | $subjectParent/ead:subject/text() |
            $subjectParent/ead:geogname/text() | $subjectParent/ead:genreform/text() | 
            $subjectParent/ead:occupation/text()
    return
        <dc:subject>{ fn:string($subject) }</dc:subject>
};
