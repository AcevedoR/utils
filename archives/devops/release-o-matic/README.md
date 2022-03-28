# release-O-matic
### Description
Uses the list-projects-to-release script (which returns a list of projects), and, launch the release
job of every project, one at a time, waiting for the previous one to finish (to avoid conflicts, in 
Integration Tests stubs for example).


Only can launch parameterized jobs

### Setup
``
pip install python-jenkins
``
``
pip install git+http://github.com/bufordtaylor/python-texttable
``

One python script is required at : ../list-projects-to-release/list-projects-to-release-script.py


If not located there then use -s "path/file.py" option

### Usage
``
python release-O-matic-script
``
##### Optionals parameters :
* Location of list-projects-to-release-script. Full path with extension required :
    * -s "path/file.py"
    * --list-projects-to-release-script-location "path/file.py"
   

* Enable ANSI color printing :
    * -c
    * --print-colors


* Enable production mode, changes job folder (to 3-PRODUCTION instead of default 1-DEV) :
    * -p
    * --production-mode
    

* Skip listed projects :
    * -S
    * --skip-projects

### Resources
[python-jenkins API reference](https://python-jenkins.readthedocs.io/en/latest/examples.html)