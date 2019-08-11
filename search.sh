#!/bin/sh

# load the extended grep functions
source grepfunctions.sh

# If user pass only one argument in command line, then we default to grepx function
# If user pass two arguments in command line, then the first argument is the name of the grep extended function
# Example: search codescan reasonForDeletion
# Otherwise, prints the usage message.
if [ $# -eq 1 ] 
then
    echo Searching \"$1\" using default extended grep function...
	grepx $1 | ansi2html.sh --bg=dark > ~/search-results/$1.grepx.html
else
	if [ $# -eq 2 ] 
	then
		echo Searching \"$2\" using extended grep function type $1...
		grepx_$1 $2 | ansi2html.sh --bg=dark > ~/search-results/$2.$1.html
	else
		echo Invalid number of arguments. Use with one or two arguments: search STRING or search FUNCTION STRING
		echo Where STRING is the string you are searching for - use double quotes if the string has one or more spaces
		echo If search is used with one argument, the extended grep function used is one that extends grep to preform a useful search for development
		echo When search is used with two arguments, FUNCTION is any string from {codescan, code, web, java, sql, xml, docs, filename, jar} where
		echo -e ' \t ' x_filename: extend grap to preform a useful search for development - but only displays the file name
		echo -e ' \t ' codescan: emulates the function of ES CodeScan tool... but actually work...
		echo -e ' \t ' android: search inside android projects
		echo -e ' \t ' code: only search code files - including xml files for spring configs
		echo -e ' \t ' web: only search web files
		echo -e ' \t ' java: only search java files
		echo -e ' \t ' java_filename: only search java files - but only displays the file name
		echo -e ' \t ' javascript: only search javascript files
		echo -e ' \t ' xhtml: only search xhtml files
		echo -e ' \t ' css: only search css files
		echo -e ' \t ' sql: only search sql, mainly for searching sql deltas
		echo -e ' \t ' xml: only search xml, mainly for searching build scripts
		echo -e ' \t ' docs: only search for documentation by file name
		echo -e ' \t ' filename: only search by file name
		echo -e ' \t ' jar: only search for jars by file name
	fi
fi
