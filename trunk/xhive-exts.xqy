xquery version "1.0";

(:
 : Module Name: XHive Extensions
 : Module Version: 1.0
 : Date: September, 2007
 : Copyright: Michael J. Giarlo
 : XQuery Specification: November 2005
 : Module Overview: X-Hive-specific hooks
 :)

(:~
 : X-Hive extensions 
 :
 : @author Michael J. Giarlo
 : @since September, 2007
 : @version 1.0
 :)

module namespace xhive-exts = 'http://diglib.princeton.edu/ns/xquery/xhive-exts';

declare default function namespace 'http://diglib.princeton.edu/ns/xquery/xhive-exts';

declare namespace xhive = 'http://www.x-hive.com/2001/08/xquery-functions';
declare namespace mods  = 'http://www.loc.gov/mods/v3';

(:~
 : Get last modified date from X-Hive/DB
 :
 : @param $_record an XML doc
 : @return xs:dateTime  
 :)
 declare function xhive-exts:last-update($_record) {
    xhive:java('edu.princeton.diglib.xhive.XQGetDocDateFunction', fn:root($_record)) cast as xs:dateTime
};
