# extended-grep

### Extend grep to perform a useful search. The script search for words inside files, and also search for files names.

Steps to configure the extended grep functions.
Note: if you are using Mac, you don't need to install cygwin,
as you already have a Linux shell and your home folder with your .bash_profile etc.

1) Install cygwin (https://www.cygwin.com). For example, I installed it at:

	C:\dev\cygwin\
	
2) Run the cygwin for the first time. This will create your home folder. For example, my home folder is:
                                                                         
    C:\dev\cygwin\home\RODOliveira

3) Create a bin folder inside your home folder. For example:
	
	C:\dev\cygwin\home\RODOliveira\bin

4) Copy files grepfunctions.sh, ansi2html.sh, and search.sh to this bin folder.

5) Find the file .bash_profile. For example, this file can be found on my machine at:

	C:\dev\cygwin\home\RODOliveira\\.bash_profile

And edit this file by adding the folder bin (created on previous step) to the the PATH, like this:

	# Set PATH so it includes user's private bin if it exists
	if [ -d "${HOME}/bin" ] ; then
	  PATH="${HOME}/bin:${PATH}"
	fi

6) Find the file .bashrc. For example, on my machine this file can be found at:

C:\dev\cygwin\home\RODOliveira\\.bashrc
 
Edit this file by adding an alias to search.sh:

	# my own shortcuts
	alias search='search.sh'

7) Create a search-results folder inside your home folder. This folder will keep all results from your searches, as html files. When listing these files, you can order them by date, so that you have your latest search files results on the top. For example, on my machine the path to this folder is:

	C:\dev\cygwin\home\RODOliveira\search-results\

8) Open a cygwin console, change directory to the folder where you want to run the search recursively, i.e. it will search inside all internal folders, minus folders like .mule, target etc (check the script grepfunctions.sh, the lines where you find --exclude-dir, for a complete list, which you are free to edit and add more folders that are irrelevant for your searches).

#### Examples of usage:

    $ search additionalId
    Searching additionalId using default extended grep function...
Find the result search file, additionalId.grepx.html, at the search-results folder.

    $ search xml Transaction-ID
    Searching Transaction-ID using extended grep function type xml...
Find the result search file, Transaction-ID.xml.html, at the search-results folder.

    $ search filename p-dcs-flightsummary
    Searching p-dcs-flightsummary using extended grep function type filename...
Find the result search file, p-dcs-flightsummary.filename.html, at the search-results folder.

#### More examples of usage:

![Search example](https://github.com/jrodolfo/extended-grep/blob/master/images/search-examples.png "Search example")

![Search results folder](https://github.com/jrodolfo/extended-grep/blob/master/images/search-results-folder.png "Search results folder")

![Search result file](https://github.com/jrodolfo/extended-grep/blob/master/images/search-result-file.png "Search result file")
