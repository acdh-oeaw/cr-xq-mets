xquery version '3.0';

module namespace abacus=http://aac.ac.at/content-repository/projects-index-functions/abacus';

declare function abacus:resource-pid($data) as item()* {
	$data//'abacus'
};



declare function abacus:resourcefragment-pid($data) as item()* {
	$data//(tei:pb|pb)/@facs
};



declare function abacus:facs-uri($data) as item()* {
	$data//(tei:pb|pb)/facs:filename-to-path(@facs,'abacus')
};



declare function abacus:title($data) as item()* {
	$data//(tei:pb|pb)[1]/(@facs|@n|@xml:id)[1]
};



declare function abacus:cql.serverChoice($data) as item()* {
	$data//tei:div[@type='page']
};



declare function abacus:ref($data) as item()* {
	$data//rs
};



declare function abacus:rs-type($data) as item()* {
	$data//rs/@type
};



declare function abacus:rs-subtype($data) as item()* {
	$data//rs/@subtype
};



declare function abacus:rs-typesubtype($data) as item()* {
	$data//rs/concat(@type,'-', @subtype)
};



declare function abacus:lemma($data) as item()* {
	$data//(tei:w/@lemma|w/@lemma)//
};



declare function abacus:pos($data) as item()* {
	$data//w/@type
};

