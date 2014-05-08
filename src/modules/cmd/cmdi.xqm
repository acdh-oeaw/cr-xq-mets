xquery version "3.0";

module namespace cmdi = "http://www.clarin.eu/cmd/";

declare variable $cmdi:profiles := doc("profiles.xml");

declare function cmdi:profile-id-to-name($profile-id as xs:string) as xs:string {
    $cmdi:profiles//profile[@id = $profile-id]/xs:string(@name)
};

declare function cmdi:name-to-profile-id($name as xs:string) as xs:string {
    $cmdi:profiles//profile[@name = $name]/xs:string(@id)
};