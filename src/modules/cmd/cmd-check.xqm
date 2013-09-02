        xquery version "1.0";
module namespace cmdcheck = "http://clarin.eu/cmd/check";
(: checking (trying to ensure) consistency of the IDs in CMD-records (MdSelfLink vs. ResourceProxies vs. IsPartOf)

TODO: check (and/or generate) the inverse links in IsPartOf (vs. ResourceProxies)
:)
   
(:import module namespace cmd  = "http://clarin.eu/cmd/collections" at "cmd-collections.xqm";:)
import module namespace repo-utils = "http://aac.ac.at/content_repository/utils" at  "../../core/repo-utils.xqm";
import module namespace fcs = "http://clarin.eu/fcs/1.0" at "../fcs/fcs.xqm";
import module namespace crday  = "http://aac.ac.at/content_repository/data-ay" at "../aqay/crday.xqm";
import module namespace smc = "http://clarin.eu/smc" at "../smc/smc.xqm";
import module namespace diag =  "http://www.loc.gov/zing/srw/diagnostic/" at  "../diagnostics/diagnostics.xqm";

declare namespace sru = "http://www.loc.gov/zing/srw/";
declare namespace cmd = "http://www.clarin.eu/cmd/";

(:~ default namespace: cmd - declared statically, because dynamic ns-declaration did not work 
cmd is the default namespace in (not) all the CMD records  
:)
(:declare default element namespace "http://www.clarin.eu/cmd/";:)
(:~ default namespace - not declared explicitely, it is declared dynamically where necessary (function: addIsPartOf() :) 
declare variable $cmdcheck:default-ns := "http://www.clarin.eu/cmd/";
declare variable $cmdcheck:root-coll := "root";


(:~ runs cmd.profile-scan for all contexts defined in the mappings :)

declare function cmdcheck:run-stats($config-path as xs:string) as item()* {

       let $config := repo-utils:config($config-path), 
           $mappings := doc(repo-utils:config-value($config, 'mappings'))
        
        let $opt := util:declare-option("exist:serialize", "media-type=text/html method=xhtml")

      for $map in $mappings//map[@key]
                let $map-key := $map/xs:string(@key),
                    $map-dbcoll-path := $map/xs:string(@path),
                    $scan-cmd-profile := fcs:scan('cmd.profile', $map-key, 1, 50, 1, 1, "text", '', $config)                                        
                return $scan-cmd-profile
};

(:~
generate a mapping out of the db-collection structure
combine it with manual configuration (expects: mappings-manual.xml in projects-config-collections)
and store it to conf
:)
declare function cmdcheck:collection-to-mapping($config,$x-context as xs:string+ ) as item()* {
    
    let $config-path := util:collection-name($config[1])
    let $context-path := repo-utils:context-to-collection-path($x-context, $config)

    let $mappings-manual := doc(concat($config-path, '/mappings-manual.xml')) 

    let $maps :=  <map>{ ($mappings-manual/map/*,
                            for $dataset-coll in xmldb:get-child-collections($context-path)
                                for $provider-coll in xmldb:get-child-collections(concat($context-path,'/',$dataset-coll))
                                    return 
                                        <map key="{$provider-coll}" label="{translate($provider-coll,'_', ' ')}" path="{concat($context-path,'/',$dataset-coll,'/',$provider-coll)}"/>
                            ) }</map>
    
     let $store := repo-utils:store($config-path ,  'mappings.xml', $maps, true(),$config)     
    return $store
};



(:~ currently not used -> DEPRECATE? 
init-function meant to call individual functions actually doing something.
at least it resolves x-context to a nodeset
:)
declare function cmdcheck:check($x-context as xs:string+, $config ) as item()* {
    
    let $log-file-name := concat('log_checks_', repo-utils:sanitize-name($x-context), '.xml')
    let $log-path := repo-utils:config-value($config, 'log.path')
    
    let $start-time := util:system-dateTime()
	
    let $stat-profiles := cmdcheck:scan-profiles($x-context, $config), 
(:        $check-linking := cmdcheck:check-linking($data-collection),:)
        $duration := util:system-dateTime() - $start-time    
    
    let $result-data := <checks context="{$x-context}" on="{$start-time}" duration="{$duration}" >
                    <profiles>{$stat-profiles}</profiles>
                    <check-linking>{$check-linking}</check-linking>
                  </checks>
     let $store := xmldb:store($log-path ,  $log-file-name, $result-data)                  
    return $store     
};

(:~ extracts CMD-Profiles from given nodeset
expects the data to be in CMD format (especially cmd-namespace)
generates a list of profile-ids
and matches each against $smc:cmd-terms (-> and diagnostics)

special handling of missing profile-ids

REMOVED dynamic handling of namespaces, just scan cmd-ns, otherwise got bad errors, when some not cmd-data was in given db-collection
also REMOVED generating a list of profile-id#profile-name pairs, as it was too expensive - and just for data-debugging (consistence checks) purposes

:)
declare function cmdcheck:scan-profiles($x-context as xs:string, $config as node()*) as item()* {
      (: try- to handle namespace problem - primitively :) 
      
    let $context := repo-utils:context-to-collection($x-context, $config),
        $ns-uri := namespace-uri($context[1]/*)  
            

let $profiles-summary := 
        if (not(exists($context))) then
            diag:diagnostics("general-error", concat("scan-profiles: no context: ", $x-context))
         else
            
             
            let $missing-profiles-records := $context//cmd:MdProfile[. = '']/ancestor::cmd:CMD
            let $missing-profiles-distinct-names := distinct-values($missing-profiles-records/cmd:Components/*/local-name())
                        
            let $missing-profiles := for $profile-name in $missing-profiles-distinct-names
                (:  if ID missing try to fill up from smc:cmd-terms :)
                 let $matching-cmd-profile := $smc:cmd-terms//Termset[xs:string(@name)=$profile-name and @type="CMD_Profile"]
                 let $profile-id := if (count($matching-cmd-profile)>0) then $matching-cmd-profile[1]/xs:string(@id) else $profile-name
                 let $cnt := count($missing-profiles-records/cmd:Components/*[local-name()=$profile-name]/ancestor::cmd:CMD)
                 let $diag :=  concat($profile-name, ' - ',
                                        "no matching profile"[$matching-cmd-profile = ()],
                                    concat("matched with profile: ",$matching-cmd-profile[1]/xs:string(@id))[count($matching-cmd-profile)=1],
                                    concat("ambiguous match with profiles: ", string-join($matching-cmd-profile/xs:string(@id),', '))[count($matching-cmd-profile)>1]
                                    )
               return <sru:term>
                           <sru:value>{$profile-id}</sru:value>                                           
                           <sru:numberOfRecords>{$cnt}</sru:numberOfRecords>
                           <sru:displayTerm>{$profile-name}</sru:displayTerm>
                           <sru:extraTermData>
                                        { diag:diagnostics("profile-id-missing", $diag) }
                                    </sru:extraTermData>                           
                         </sru:term>
          
           let $profile-ids := distinct-values($context//cmd:MdProfile)
            
            let $profiles := for $profile-id in $profile-ids[. ne '']
                        let $records := $context//cmd:MdProfile[. = $profile-id]/ancestor::cmd:CMD
                        let $profile-name := ($records)[1]/cmd:Components/*[1]/local-name()
                        let $cnt := count($records)
                        
                        let $matching-cmd-profile := $smc:cmd-terms//Termset[xs:string(@id)=$profile-id and @type="CMD_Profile"]
                        (: check if the defined name of the profile matches with the base-component element in the data (at least the first record we took as sample *sigh* :)
                        let $profile-name-matching :=  ($profile-name = $matching-cmd-profile/xs:string(@name))
                        
                    (: for debugging mainly, to check if there are more base-components (cmd:Components/*) associated with one id
                       but prohibitively slow for larger datasets - 
                       let $distinct-base-components := distinct-values($records/cmd:Components/*/local-name())
                       alternatively just check, if there is another record with the same profile-id, but other local-name - a bit less slow :)
                    (:  let $other-base-comp:= $records/cmd:Components/*[xs:string(local-name()) ne $first-base-comp]/local-name(.):)
                                
                                return <sru:term>
                                           <sru:value>{$profile-id}</sru:value>                                           
                                           <sru:numberOfRecords>{$cnt}</sru:numberOfRecords>
                                           <sru:displayTerm>{$profile-name}</sru:displayTerm>
                                           { if ($matching-cmd-profile = () or not($profile-name-matching)) then
                                                    <sru:extraTermData>
                                                        { (diag:diagnostics("profile-unknown", $profile-id)[not(exists($matching-cmd-profile))] ,
                                                          diag:diagnostics("profile-name-mismatch", 
                                                                    concat($profile-name, '!=', $matching-cmd-profile/xs:string(@name)))[exists($matching-cmd-profile) and not($profile-name-matching)]
                                                           )
                                                        }
                                                    </sru:extraTermData>
                                                  else ()
                                                  }
                                         </sru:term>
                                         
           return ($profiles, $missing-profiles)
           
    let $count-all := count($profiles-summary)                                        
    return
                    <sru:scanResponse xmlns:sru="http://www.loc.gov/zing/srw/" xmlns:fcs="http://clarin.eu/fcs/1.0">
                          <sru:version>1.2</sru:version>              
                          <sru:terms>              
                            {$profiles-summary }
                           </sru:terms>
                           <sru:extraResponseData>
                                 <fcs:countTerms>{$count-all}</fcs:countTerms>
                             </sru:extraResponseData>
                             <sru:echoedScanRequest>                      
                                  <sru:scanClause>cmd.profile</sru:scanClause>
                              </sru:echoedScanRequest>
                       </sru:scanResponse>    
};


declare function cmdcheck:display-overview($config) as item()* {

(:$config := repo-utils:config($config-path),:)
   let 
       $dummy := util:declare-namespace("",xs:anyURI("")),
       $mappings := doc(repo-utils:config-value($config, 'mappings'))
(:       $baseurl := repo-utils:config-value($config, 'base.url'),:)
        
   let $opt := util:declare-option("exist:serialize", "media-type=text/html method=xhtml")                       

(:   let $overview :=  crday:display-overview($config-path, 'raw'):)
   let $overview :=  "temporarily deactivated (not updated yet): crday:display-overview($config-path, 'raw')"
    
   let $profiles-overview :=  <table class="show"><tr><th>collection</th><th>profiles</th></tr>
           { for $map in util:eval("$mappings//map[@key]")
                    let $map-key := $map/xs:string(@key),
                        $map-dbcoll-path := $map/xs:string(@path),
                        $scan-cmd-profile := fcs:scan('cmd.profile', $map-key, 1, 50, 1, 1, "text", '', $config),   
                        $scan-formatted := repo-utils:serialise-as( $scan-cmd-profile, 'htmldetail', 'scan', $config, ())
                    return <tr>
                        <td>{$map-key}</td>
                        <td>{ $scan-formatted }</td>
                        </tr>
                        }
        </table>
            (: { for $profile in $scan-cmd-profile//sru:term 
                            return ($profile/sru:value, $profile/sru:displayTerm, $profile/sru:numberOfRecords)
                        }:)

        return repo-utils:serialise-as( <div>{($overview, $profiles-overview)}</div>, 'htmlpage', 'html', $config, ())
        
};




(:~	WARNING - CHANGES DATA! adds IsPartOf to the CMDrecords (contained in the db-coll)
- expects CMD-records for collections in specific db-coll (with name of the db-coll matching the name of the collectionfile):
    ./_corpusstructure/collection_{db-coll-name}.cmdi
- logs the progress of the processing in a separate file
- can be applied repeatedly - deletes(!) old IsPartOfList, before inserting new

@param $x-context an identifier of a collection (as defined in mappings)
@param $config config-node - used to get log.path and collection-path

TODO: could also generate the CMD-records for collections (assuming db-colls as collections) 
      (now done by the python script: dir2cmdicollection.py)
TODO: currently a hack: the collection-records also are marked as root elements - this has to be optional at least, 
      and may even be dangerous (count(IsPartOf[@level=1])>1)!
TODO: not recursive yet!
:)
declare function cmdcheck:addIsPartOf-colls($x-context as xs:string, $config as node()*) as item()* {

let $log-file-name := concat('log_addIsPartOf_', $x-context, '.xml')
    let $log-path := repo-utils:config-value($config, 'log.path')
    let $log-doc-path := xmldb:store($log-path ,  $log-file-name, <result></result>)
    let $log-doc := doc($log-doc-path)
    
    (:let $root-dbcoll := repo-utils:context-to-collection($x-context, $config),:)
    let $root-dbcoll-path := repo-utils:context-to-collection-path($x-context, $config)
    
    let $coll-dbcoll := '_corpusstructure'
     
    (: beware empty path!! would return first-level collections and run over whole database :) 
    let $colls := if ($root-dbcoll-path ne "") then xmldb:get-child-collections($root-dbcoll-path) else ()
    let $start_time := fn:current-dateTime()
    
    (: dynamic ns-declaration does not work for xpath 
    let $declare-dummy := util:declare-namespace("",xs:anyURI($cmdcheck:default-ns))
    :)
    let $log-dummy := update insert <edit x-context="{$x-context}" root-dbcoll="{$root-dbcoll-path}" 
                        coll-dbcoll="{$coll-dbcoll}" count-colls="{count($colls)}" time="{$start_time}" /> into $log-doc/result
    (:if (exists($colls)) then:)
    for $coll_name in $colls[not(.=$coll-dbcoll)]
    (: let $coll_name := 'HomeFamilyManagement' :)
    let $files := collection(concat($root-dbcoll-path,$coll_name))
    (: let $files := xmldb:xcollection($root_coll) :)	
	let $coll_file := concat($root-dbcoll-path, $coll-dbcoll, '/collection_', $coll_name, '.cmdi')
	let $coll_doc := doc($coll_file)
	let $coll_id := $coll_doc//MdSelfLink/text()

(:	let $cmdi_files := $files[ends-with(util:document-name(.),".cmdi")]:)

    let $pre_time := util:system-dateTime()
	let $duration := $pre_time - $start_time
 return	( update insert <edit coll="{$coll_name}" collid="{$coll_id}" coll_file="{$coll_file}" count="{count($files)}" time="{$pre_time}" /> into $log-doc/result, 
			update delete $files//IsPartOfList,
			update delete $coll_doc//IsPartOfList,
			update insert <IsPartOfList>
								<IsPartOf level="1">{$x-context}</IsPartOf>
								<IsPartOf level="1">{$cmdcheck:root-coll}</IsPartOf>
						  </IsPartOfList>
			  	into $coll_doc//Resources,
			update insert <IsPartOfList>
							<IsPartOf level="2">{$x-context}</IsPartOf>
							<IsPartOf level="1">{$coll_id}</IsPartOf>
						  </IsPartOfList> 
				into $files//Resources,
		update value $log-doc/result/edit[last()] with (util:system-dateTime() - $pre_time)
        )
    (:
    return	($coll_name, count($cmdi_files), $coll_file,  update insert <IsPartOfList>
							<IsPartOf level="1">{$coll_id}</IsPartOf>
						  </IsPartOfList> into $cmdi_files//Resources ):)
};

(:~ recursive addIsPartOf 
starts by finding "orphaned" mdrecords = expecting that to be the root records.
and continues  ?
:)
declare function cmdcheck:addIsPartOf($x-context as xs:string, $config as node()*) as item()* {

let $log-file-name := concat('log_addIsPartOf_', $x-context, '.xml')
    let $log-path := repo-utils:config-value($config, 'log.path')
    let $log-doc-path := xmldb:store($log-path ,  $log-file-name, <result></result>)
    let $log-doc := doc($log-doc-path)
    
    let $root-dbcoll := repo-utils:context-to-collection($x-context, $config),
        $root-dbcoll-path := repo-utils:context-to-collection-path($x-context, $config)
    
(:    let $coll-dbcoll := '_corpusstructure':)
     
    (: beware empty path!! would return first-level collections and run over whole database :) 
    let $colls := if ($root-dbcoll-path ne "") then xmldb:get-child-collections($root-dbcoll-path) else ()
    let $start_time := fn:current-dateTime()
   
    
    let $log-dummy := update insert <edit x-context="{$x-context}" root-dbcoll="{$root-dbcoll-path}" 
                         count-colls="{count($colls)}" time="{$start_time}" /> into $log-doc/result
                        
    let $root := cmdcheck:addIsPartOf-root($root-dbcoll, $log-doc)                        
    let $updated := cmdcheck:addIsPartOf-r($root-dbcoll, $root, 1, $log-doc)
    
    return $log-doc
 };
 
 (:~ consider those, whose MdSelfLink isn't referenced anywhere (orphans) as the root-cmd-collections 
 @returns the edited records :) 
 declare function cmdcheck:addIsPartOf-root($context as node()*, $log-doc as node()*) as item()* {
 
    let $pre_time := util:system-dateTime()
 
    let $orphaned := $context//CMD[not(Header/MdSelfLink = $context//ResourceProxy[ResourceType eq 'Metadata']/ResourceRef)]

    let $update := ( update insert <edit collid="root" count="{count($orphaned)}" time="{$pre_time}" /> into $log-doc/result, 
			update delete $orphaned//IsPartOfList,
			update insert <IsPartOfList>
			                 <IsPartOf>{$cmdcheck:root-coll}</IsPartOf>					
						  </IsPartOfList>  
				into $orphaned//Resources,		
		  update value $log-doc/result/edit[last()] with (util:system-dateTime() - $pre_time)
        )
 
    return $orphaned
 
 };
 
 declare function cmdcheck:addIsPartOf-r($context as node()*, $parents as node()*, $level as xs:integer, $log-doc as node()*) as item()* {
    
    let $start_time := util:system-dateTime()
    let $log-dummy := update insert <edit level="{$level}"  
                        count-colls="{count($parents)}" time="{$start_time}" /> into $log-doc/result
    
  let $update := for $cmd-record in $parents  
                    let $parent-id := $cmd-record//MdSelfLink/text()
                    let $children := $context//CMD[Header/MdSelfLink = $cmd-record//ResourceRef]    
                	let $ispartoflist := <IsPartOfList>{($cmd-record//IsPartOfList/IsPartOf[not(text()=$cmdcheck:root-coll)],
                								<IsPartOf >{$parent-id}</IsPartOf>) }					
                						  </IsPartOfList>  
                
                    let $pre_time := util:system-dateTime()
                	let $duration := $pre_time - $start_time
                    return	( update insert <edit collid="{$parent-id}" count="{count($children)}" time="{$pre_time}" /> into $log-doc/result, 
                			update delete $children//IsPartOfList,
                			update insert $ispartoflist 
                				into $children//Resources,		
                		  update value $log-doc/result/edit[last()] with (util:system-dateTime() - $pre_time)
                        )
    
    (: go next level - we dont have to recurse in the update-loop, 
     but we can do whole next level in one call :)
    let $next-level := $context//CMD[Header/MdSelfLink = $parents//ResourceRef]
    let $updated := if (exists($next-level)) then  cmdcheck:addIsPartOf-r($context, $next-level ,($level+1),$log-doc)
                        else ()
    return $update                     
};

