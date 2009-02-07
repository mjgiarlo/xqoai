xquery version "1.0";

(:
 : Module Name: xqOAI
 : Module Version: 1.0
 : Date: September, 2007
 : Copyright: Michael J. Giarlo and Winona Salesky
 : Proprietary XQuery Extensions Used: X-Hive/DB 
 : XQuery Specification: November 2005
 : Module Overview: OAI-PMH data provider for MODS records within an X-Hive/DB
 :)

(:~
 : OAI-PMH data provider for MODS records within an X-Hive/DB 
 :
 : @author Michael J. Giarlo
 : @author Winona Salesky
 : @since September, 2007
 : @version 1.0
 :)

(: import modules for extracting DC from MODS, extracting DC from EAD, and for X-Hive extensions to XQuery :)
import module namespace mods-to-dc = "http://diglib.princeton.edu/ns/xquery/mods-to-dc" at "http://diglib.princeton.edu/oai/mods-to-dc.xqy";
import module namespace ead-to-dc  = "http://diglib.princeton.edu/ns/xquery/ead-to-dc"  at "http://diglib.princeton.edu/oai/ead-to-dc.xqy";
import module namespace xhive-exts = "http://diglib.princeton.edu/ns/xquery/xhive-exts" at "http://diglib.princeton.edu/oai/xhive-exts.xqy"; 

(: declare namespaces for each metadata schema we care about :)
declare namespace mods = 'http://www.loc.gov/mods/v3';
declare namespace ead  = "http://diglib.princeton.edu/ead/";

(: configurable variables :)
declare variable $base-url           := 'http://diglib.princeton.edu/oai';
declare variable $repository-name    := 'Princeton University Library Digital Collections';
declare variable $admin-email        := 'mgiarlo@princeton.edu';
declare variable $hits-per-page      := 10000;
declare variable $earliest-datestamp := '1990-01-01T00:00:00Z' cast as xs:dateTime;
declare variable $db-paths           := '/newDigLib', '/ead';
declare variable $oai-domain         := 'diglib.princeton.edu';
declare variable $id-scheme          := 'oai';

(: params from OAI-PMH spec :)
declare variable $verb            external;
declare variable $identifier      external;
declare variable $metadataPrefix  external;  
declare variable $set             external;
declare variable $from            external;
declare variable $until           external;
declare variable $resumptionToken external;

(: set to true in argstring for extra debugging information :)
declare variable $verbose         external;

(: resumption token for paging :)
declare variable $start := local:get-cursor-token();

(:~
 : Print datetime of OAI response. 
 : - Uses substring and concat to get the date in the format OAI wants
 :
 : @return XML
 :)
declare function local:oai-response-date() {
    <responseDate>{ 
        concat(substring(current-dateTime() cast as xs:string, 1, 19), 'Z') 
    }</responseDate>
};

(:~
 : Build the OAI request element 
 :
 : @return XML
 :)
declare function local:oai-request() {
   element request {
       if ($verb != '')            then attribute verb {$verb}                       else (),
       if ($identifier != '')      then attribute identifier {$identifier}           else (),
       if ($metadataPrefix != '')  then attribute metadataPrefix {$metadataPrefix}   else (),
       if ($from != '')            then attribute from {$from}                       else (),
       if ($until != '')           then attribute until {$until}                     else (),
       if ($set != '')             then attribute set {$set}                         else (),
       if ($resumptionToken != '') then attribute resumptionToken {$resumptionToken} else (),
       $base-url
   }
};

(:~
 : Main brancher
 : - validate params if verb is neither identify or listmetadataformats
 : - else go straight to a response
 :
 : @return nothing
 :)
declare function local:oai-main() {
    if (not($verb = 'Identify' or $verb = 'ListMetadataFormats')) then
        local:validate-params()
    else 
        local:oai-response('', '', '') 
};

(:~
 : Get resumptionToken
 : - this is a stub
 : TO-DO: real resumptionTokens, using xquery update to store result sets in the db
 :
 : @return valid resumptionToken in appropriate format
 :)
declare function local:get-cursor-token() {
    if ($resumptionToken = '' or not(matches($resumptionToken, '^\d+,oai_dc,\d+(,.+)*$'))) then 
        1
    else 
        $resumptionToken cast as xs:integer
};

(:~
 : Validate client-supplied parameters
 :
 : @return XML if errors, nothing if not
 :)
declare function local:validate-params() {
    let $errors := 
        if ($verb = 'GetRecord') then
            if ($identifier = '') then <error code="badArgument">identifier is a required argument</error> else (),
            if ($metadataPrefix = '') then <error code="badArgument">metadataPrefix is a required argument</error> else (),
            if ($metadataPrefix != 'oai_dc') then <error code="cannotDisseminateFormat">only oai_dc is supported</error> else ()
        else if ($verb = 'ListIdentifiers' or $verb = 'ListRecords') then 
            if ($resumptionToken != '' and not(matches($resumptionToken, '^\d+$'))) then <error code="badResumptionToken">bad resumptionToken</error> else (),
            if ($metadataPrefix = '') then <error code="badArgument">metadataPrefix is a required argument</error> else (),
            if ($metadataPrefix != 'oai_dc') then <error code="cannotDisseminateFormat">only oai_dc is supported</error> else (),
            if (not(local:validate-dates())) then <error code="badArgument">from or until arguments not valid format</error> else ()
        else if ($verb = 'ListSets') then
            if ($resumptionToken != '' and not(matches($resumptionToken, '^\d+$'))) then <error code="badResumptionToken">bad resumptionToken</error> else ()
        else <error code="badVerb">Invalid OAI-PMH verb : { $verb }</error>
    return 
        if (empty($errors)) then
            local:get-docs()
        else
            $errors
};

(:~
 : Validate from and until params
 : - dates are valid only if they match date-pattern and are in same format
 : - note that date-pattern also matches an empty string
 :
 : @return boolean
 :)
declare function local:validate-dates() {
    let $date-pattern := '^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z){0,1}$'
    let $from-len     := string-length($from)
    let $until-len    := string-length($until)
    return
        if ($from-len > 0 and $until-len > 0 and $from-len != $until-len) then
            false
        else
            matches($from, $date-pattern) and matches($until, $date-pattern)
};

(:~
 : Get collection of (MODS and EAD) docs from database
 : - iterate over config variable db-paths to grab data from appropriate areas of db
 : - the mods and ead xpaths are hard-coded at this point in time
 : TO-DO: do away with hard-coding 
 :
 : @return XML if errors, nothing if not
 :)
declare function local:get-docs() {
    let $docs := 
        for $path in $db-paths
        let $root := collection($path)
        return
            $root//mods:mods[@ID='work' or not(exists(@ID))][child::mods:identifier[exists(@type) and @type='oai']] | $root/ead:ead
    let $hits := local:build-query($docs)
    return
        if (empty($hits/child::*)) then 
            if ($verb = 'GetRecord') then 
                <error code="idDoesNotExist">No matching identifier in archive</error>
            else if ($verb = 'ListIdentifiers' or $verb = 'ListRecords') then 
                <error code="noRecordsMatch">No records match</error>
            else if ($verb = 'ListSets' ) then 
                <error code="noSetHierarchy">This repository does not support sets</error>
            else ()
        else local:paginate($hits)    
};

(:~
 : Build the query string depending on "verb" param
 : - there's hard-coding in listsets that prevents pulling ead sets, currently
 : TO-DO: change this to allow for ead sets, depending on what ead folks want
 :
 : @param $_docs a sequence of XML docs
 : @return sequence of XML docs, a subset of the $_docs param
 :)
declare function local:build-query($_docs) {
    if ($verb = 'ListSets') then
        for $record in $_docs[child::mods:identifier[@type = 'oai' and count(tokenize(text(), ':')) = 3]]
        return $record
    else if ($verb = 'GetRecord') then 
        for $record in $_docs
        where local:get-identifier($record) = $identifier
        return $record 
    else if ($verb = 'ListRecords' or $verb = 'ListIdentifiers') then
        for $record in $_docs
        where local:date-range($record) and local:set-check($record) 
        return $record
    else ()
};

(:~
 : Filter the result set based on client-supplied date params
 :
 : @param $_record an XML doc
 : @return an XML doc
 :)
declare function local:date-range($_record) {
    if ($from = '' and $until = '' ) then $_record
    else
        let $from := 
            if ($from = '') then $earliest-datestamp
            else if (matches($from, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$')) then $from cast as xs:dateTime
            else ()
        let $until := 
            if ($until = '') then $earliest-datestamp
            else if (matches($until, '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$')) then $until cast as xs:dateTime
            else ()
        let $record-date := xhive-exts:last-update($_record)
        return
            if ($record-date = $earliest-datestamp) then
                $_record
            else if ($until = $earliest-datestamp) then 
                $_record[$record-date >= $from]
            else if ($from = $earliest-datestamp) then 
                $_record[$record-date <= $until]
            else 
                $_record[$record-date >= $from and $record-date <= $until]
};

(:~
 : Filter the result set to just collections if $set is specified
 : - set detection is hard-coded with mods values
 : TO-DO: remove hard-coding to allow for more flexible set grabs
 :
 : @param $_record an XML doc
 : @return an XML doc
 :)
declare function local:set-check($_record) {
    if ($set = '') then 
        $_record 
    else
        $_record[child::mods:identifier[@type='oai' and text()=$set]] or $_record[child::mods:relatedItem[@type='host']/mods:identifier[@type='oai' and text()=$set]]
};

(:~
 : Handle pagination of result set
 : - resumptionTokens not currently used, so this is a stub for the future
 : TO-DO: fix this up when building resumptionToken support
 :
 : @param $_hits a sequence of XML docs
 : @return XML 
 :)
declare function local:paginate($_hits) {
    let $count := count($_hits)
    let $max := $hits-per-page
    let $end := 
        if ($start + $max - 1 < $count) then 
            $start + $max - 1 
        else 
            $count
    return (
        if ($verbose = 'true') then 
            <query-results hits="{ $count }" start="{ $start }" next="{ $end }" max="{ $max }"/> 
        else 
            (),
        local:oai-response($_hits, $end, $count)
     )
};

(:~
 : Branch processing based on client-supplied "verb" param
 :
 : @param $_hits a sequence of XML docs
 : @param $_end an integer reflecting the last item in the current page of results
 : @param $_count an integer reflecting total hits in the result set
 : @return XML if errors, nothing if not
 :)
declare function local:oai-response($_hits, $_end, $_count) { 
    if      ($verb = 'ListSets')            then local:oai-list-sets($_hits, $_end, $_count)
    else if ($verb = 'ListRecords')         then local:oai-list-records($_hits, $_end, $_count)
    else if ($verb = 'ListIdentifiers')     then local:oai-list-identifiers($_hits, $_end, $_count)
    else if ($verb = 'GetRecord')           then local:oai-get-record($_hits)
    else if ($verb = 'ListMetadataFormats') then local:oai-list-metadata-formats()
    else if ($verb = 'Identify')            then local:oai-identify()
    else <error code="badVerb">Invalid OAI-PMH verb : { $verb }</error>        
};

(:~
 : Print an OAI-PMH header
 : - uses an xhive-specific extension to retrieve the last-modified datetime of the record
 :
 : @param $_record an XML record
 : @return XML
 :)
declare function local:oai-header($_record) {
    let $identifier := 
        if ($identifier != '') then 
            $identifier
        else 
            local:get-identifier($_record)
    return
        <header>
          <identifier>{ $identifier }</identifier> 
          <datestamp>{ xhive-exts:last-update($_record) }</datestamp>
          {
              if ($set != '') then 
                  <setSpec>{ $set }</setSpec> 
              else 
                  ()
          }
        </header>
};

(:~
 : Print a metadata record
 : - the mods/ead brancher is inelegant -- more abstraction may be helpful here
 : TO-DO: find a way to make this easier to extend, e.g., for new metadata formats
 :
 : @param $_record an XML record
 : @return XML
 :)
declare function local:oai-metadata($_record) {
    let $identifier := 
        if ($identifier != '') then 
            $identifier
        else 
            local:get-identifier($_record)
    return
      <metadata>{
          if ($metadataPrefix = 'oai_dc') then 
              <oai_dc:dc xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/" 
                         xmlns:dc="http://purl.org/dc/elements/1.1/" 
                         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
                         xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd">{
              let $top-node-name := local-name(root($_record)/*[1])
              return
              if ($top-node-name = 'mods' or $top-node-name = 'modsCollection') then
                  mods-to-dc:get-identifier($_record),
                  mods-to-dc:get-title($_record),  
                  mods-to-dc:get-creator($_record), 
                  mods-to-dc:get-subject($_record),
                  mods-to-dc:get-description($_record),
                  mods-to-dc:get-date($_record),
                  mods-to-dc:get-contributor($_record),
                  mods-to-dc:get-relation($_record)
              else if ($top-node-name = 'ead') then
                  ead-to-dc:get-identifier($_record),
                  ead-to-dc:get-title($_record),
                  ead-to-dc:get-creator($_record),
                  ead-to-dc:get-subject($_record),
                  ead-to-dc:get-description($_record),
                  ead-to-dc:get-date($_record),
                  ead-to-dc:get-rights($_record),
                  ead-to-dc:get-publisher($_record)
              else
                  ()
              }</oai_dc:dc> 
          else 
              <error code="cannotDisseminateFormat"/>
      }</metadata>
};

(:~
 : Extract OAI identifier from MODS or EAD
 : - currently assumes only mods and ead are relevant
 : TO-DO: get rid of hard-coding
 :
 : @param $_record an XML record
 : @return a string representing an OAI identifier
 :)
declare function local:get-identifier($_record) {
    if (exists($_record[ancestor-or-self::mods:mods])) then
        $_record/mods:identifier[@type='oai']/text()
    else
        string($_record/ead:eadheader/ead:eadid/@urn)
};

(:~
 : Print the resumptionToken
 : TO-DO: fix this up when resumptionToken support is built-in
 :
 : @param $_end integer, index of last item in current page of results
 : @param $_count integer, total number of hits in result set
 : @return XML or nothing
 :)
declare function local:print-token($_end, $_count) {
    if ($_end + 1 < $_count) then 
        let $token :=  $_end + 1  
        return
            <resumptionToken completeListSize="{ $_count }" cursor="{ $start - 1 }">{ $token }</resumptionToken>
    else 
        ()
};

(:~
 : OAI GetRecord verb
 :
 : @param $_hits a sequence of XML docs
 : @return XML corresponding to a single OAI record
 :)
declare function local:oai-get-record($_hits) {
    let $record := $_hits
    return 
        <GetRecord>
            <record>{  
              local:oai-header($record),
              local:oai-metadata($record) 
            }</record>
            { 
                if ($verbose = 'true') then 
                    <debug>{ $record }</debug> 
                else 
                    () 
            }
        </GetRecord> 
};

(:~
 : OAI Identify verb
 :
 : @return XML describing the OAI provider
 :)
declare function local:oai-identify() {
      <Identify>
        <repositoryName>{ $repository-name }</repositoryName>
        <baseURL>{ $base-url }</baseURL>
        <protocolVersion>2.0</protocolVersion>
        <adminEmail>{ $admin-email }</adminEmail>
        <earliestDatestamp>{ $earliest-datestamp }</earliestDatestamp>
        <deletedRecord>transient</deletedRecord>
        <granularity>YYYY-MM-DDThh:mm:ssZ</granularity>
        <description>
        	<oai-identifier xmlns="http://www.openarchives.org/OAI/2.0/oai-identifier" 
        	                xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai-identifier http://www.openarchives.org/OAI/2.0/oai-identifier.xsd">
                <scheme>{ $id-scheme }</scheme>
                <repositoryIdentifier>{ $oai-domain }</repositoryIdentifier>
                <delimiter>:</delimiter>
                <sampleIdentifier>{ concat($id-scheme, ':', $oai-domain, ':postcards:23')  }</sampleIdentifier>
            </oai-identifier>
        </description>
     </Identify>
};

(:~
 : OAI ListIdentifiers verb
 :
 : @param $_hits a sequence of XML docs
 : @param $_end integer, index of last item in page of results
 : @param $_count integer, total number of hits in result set
 : @return XML corresponding to a list of OAI identifier records
 :)
declare function local:oai-list-identifiers($_hits, $_end, $_count) {
    <ListIdentifiers>{
        for $i in $start to $_end
        let $record := item-at($_hits, $i)
        return (
            local:oai-header($record),
            if ($verbose = 'true') then 
                <debug>{ $record }</debug> 
            else 
                ()
        )        
    } 
    { 
        local:print-token($_end, $_count)
    }</ListIdentifiers>
};

(:~
 : OAI ListMetadataFormats verb
 :
 : @return XML corresponding to a list of supported metadata formats
 :)
declare function local:oai-list-metadata-formats() {
    <ListMetadataFormats>
      <metadataFormat>
        <metadataPrefix>oai_dc</metadataPrefix>
        <schema>http://www.openarchives.org/OAI/2.0/oai_dc.xsd</schema>
        <metadataNamespace>http://www.openarchives.org/OAI/2.0/oai_dc/</metadataNamespace>
      </metadataFormat>
    </ListMetadataFormats>
};

(:~
 : OAI ListRecords verb
 :
 : @param $_hits a sequence of XML docs
 : @param $_end integer, index of last item in page of results
 : @param $_count integer, total number of hits in result set
 : @return XML corresponding to a list of full OAI records
 :)
declare function local:oai-list-records($_hits, $_end, $_count) {
    <ListRecords>{
      for $i in $start to $_end
      let $record := item-at($_hits, $i)
      return
          <record>{ 
            local:oai-header($record),
            local:oai-metadata($record),
            if ($verbose = 'true') then
                <debug>{ $record }</debug> 
            else 
                ()
          }</record>
      }
      { 
        local:print-token($_end, $_count)
      }</ListRecords>
};

(:~
 : OAI ListSets verb
 :
 : @param $_hits a sequence of XML docs
 : @param $_end integer, index of last item in page of results
 : @param $_count integer, total number of hits in result set
 : @return XML corresponding to a list of OAI set records
 :)
declare function local:oai-list-sets($_hits, $_end, $_count) {
    <ListSets>{
        for $i in $start to $_end
        let $record := item-at($_hits, $i)        
        let $collectionId := $record/mods:identifier[@type='oai']/text()
        let $title := $record/mods:titleInfo/mods:title/text() 
        return (
             <set>
                 <setSpec>{ $collectionId }</setSpec>
                 <setName>{ $title }</setName>
             </set>,
             if ($verbose = 'true') then 
                 <debug>{ $record }</debug> 
             else 
                 () 
        )
    }
    { 
        local:print-token($_end, $_count)
    }</ListSets>
};

(: OAI-PMH wrapper for request and response elements :)
<OAI-PMH xmlns="http://www.openarchives.org/OAI/2.0/" 
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
         xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/ http://www.openarchives.org/OAI/2.0/OAI-PMH.xsd">{ 
    local:oai-response-date(),
    local:oai-request(), 
    local:oai-main() 
}</OAI-PMH>  