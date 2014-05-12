#!/usr/bin/env python

# analyze xquery call-deps
# recognizes modules, comments and function-scope

# TODO: handle overloaded functions (with different params-count)  - either unify, or consider number of params
   # http://www.peterbe.com/plog/uniqifiers-benchmark

# arguments: input-file prefix
# ;input-file :: either name of the file to read in or "-" for stdin
# ;title :: title to name the result
# ;prefix :: prefix to strip from the function-names  (default = ":")
# ;parts :: parts to render (imports, clusters, calls)

import sys, os, datetime, re
from string import Template

# code_file = "cmd-model_r.xqm"
#default_prefix = "cmd-model:"
default_prefix = ":"
default_parts = "imports"

def main():	

  input = sys.argv[1]

  if len(sys.argv) > 2:
    title = sys.argv[2] + " calls"
  else:
    title = "code calls"

  if len(sys.argv) > 3:
    parts = sys.argv[3]
  else:
    parts = default_parts

  if len(sys.argv) > 4:
    prefix = sys.argv[4]
  else:
    prefix = default_prefix


  if input=="-":
    # read stdin
    lines = sys.stdin.readlines()
    # print lines
  else:
 		# Datei lesen
    try:
        f = open(input, 'r')
        lines = f.readlines()
        inputbase = os.path.dirname(input)
        #while 1:
        #    zeile = datei.readline()
         #   if zeile == '':
          #      break
           # zeilen.append(zeile)
        f.close()
    except IOError:
        print (input, "ist nicht lesbar!")
        sys.exit(1)

	
	#f = open(code_file, 'r')
	#lines = f.readlines()
	
  fns = []
  
  modules_ns = {}
  modules_fns = {}  
  curr_module = "default_module"
  modules_fns[curr_module] = []
  lines_imported = []
  lines_imported.extend(lines)
  # extend lines (with imported files
  for line in lines:  
    if line.startswith("import module"):
    	 m = re.compile("import module namespace\s+(.+?)\s*=\s*\"(.+?)\"\s+at\s+\"(.*?)\"").search(line)
    	 if m:
    	 		importfile = inputbase + "/" + m.group(3)
     			try:
     				#print ("trying: ",  importfile)
     				#print ("relative to: ",  inputbase)
     				
     				g = open(importfile, 'r')
     				lines_imported.extend(g.readlines())
     				    #while 1:
				        #    zeile = datei.readline()
				        #   if zeile == '':
				        #      break
				        # zeilen.append(zeile)
     				g.close()
     			except IOError:
     				sys.stderr.write("WARNUNG: " + importfile + " importfile ist nicht lesbar\n")
     				#sys.exit(1)
     				
     				
  for line in lines_imported:  
    if line.startswith("module namespace"):      
      m = re.compile("module namespace (.*?)\s*\=\s*\"(.*?)\"").search(line)
      if m:
        curr_module = m.group(1)
        modules_ns[curr_module] = m.group(2)  		
        modules_fns[curr_module] = []
    if "declare function" in line:
       m = re.compile("declare function (.*?)\(").search(line)
       if not(m) :  # cater for syntax, where parameters + brackets are in separate lines (functx-case)
         m = re.compile("declare function (.*?) ").search(line)       
       if m : 
         # DEBUG: sys.stderr.write(m.group(1) + "; ")
       # map function to the file it is in
         fns.append(m.group(1))
       # map function to the module it is in       
         modules_fns[curr_module].append(m.group(1))
       
       
	

  title_ = title.replace(" ", "_").replace("-", "_")
	
  print (" /* dot -o" + title_ + ".png -Tpng " + title_ + ".dot */ ")
  print ("digraph " + title_ + " {")
  print ("label=\"" + title + "\";")
  print ("rankdir=LR;")
			 
  #print "DEBUG:", fns;
   
  if "clusters" in parts:
    for module in modules_ns:
	    print ("  subgraph cluster_" + module.replace("-","_") +  " {")
	    print ("    label=\"" + module + "\";")
	      # get the functions for the module
	    for fn in modules_fns[module]:
	      print ("    " + fn.replace(prefix,"_").replace("-","_") +  "[label=\"" + fn + "\"];");
	    print ("  }")
	    
  
  curr_f = "_start"
  curr_file = "_file"
  curr_i = 1
  comment = 0
  for line in lines:
  	
    #if line.startswith("FILE:"): # set file context (and use as default, i.e. if out of function)    
    #   m = re.compile("FILE:(.*?)/([^\/]*?)\.(...?)").search(line)
    
    #import module namespace templates="http://exist-db.org/xquery/templates" at "templates.xql";
    if line.startswith("import module"):
    	 m = re.compile("import module namespace\s+(.+?)\s*=\s*\"(.+?)\"\s+at\s+\"(.*?)/?([^\/]*?)\"").search(line)
    	 if m:
    	   #print ("File: " + m.group(1) + '-' +m.group(2) )
    	   imported_file = m.group(4)
    	   if "imports" in parts and comment==0:
    	     print (curr_f.replace(prefix,"_").replace("-","_"),  "->", imported_file.replace(".","_").replace("-","_"), ";")            
    elif str("\<f" in line): # set file context (and use as default, i.e. if out of function)
    	 m = re.compile("\s*\<f n=\"([^\/]*)\.(...?)\"").search(line)
    	 if m:
    	   #print ("File: " + m.group(1) + '-' +m.group(2) )
    	   curr_file_ = m.group(1) + '.' +m.group(2)
    	   curr_file = curr_file_.replace(".","_").replace("-","_")
    	   print (curr_file, "[shape=box,label=\"" + curr_file_ + "\", URL=\"" + curr_file_.replace(".","_") + ".png\"];")
    	   curr_f = curr_file
    if "};" in line: # out of function context
      curr_f = curr_file
    elif "(:" in line: # set comment environment
      if not(":)") in line: comment = 1
    elif ":)" in line: # unset comment environment
      comment=0
    elif not("declare function") in line:
      if comment==0:
        for fn in fns:
          # "(" added, to match only full function names
          found = line.find(fn+"(") +  line.find(fn+" (")
          if found > -1:
            # this is the actual output 
            if "calls" in parts:
            	print (curr_f.replace(prefix,"_").replace("-","_"),  "->", fn.replace(prefix,"_").replace("-","_"), "[label=" , curr_i , "];")			 	  
            	curr_i = curr_i + 1
    else: 
      m = re.compile("declare function (.*?)\(").search(line)
      if not(m) :  # cater for syntax, where parameters + brackets are in separate lines (functx-case)
         m = re.compile("declare function (.*?) ").search(line)       
      if m : 
        curr_f = m.group(1)
        curr_i = 1

  print ("}")
			 
main()

