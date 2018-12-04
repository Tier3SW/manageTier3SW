#! /usr/bin/env python
#!----------------------------------------------------------------------------
#!
#! A wrapper to mimic Linux bash getopt for both long and short opts
#! (this is primarily for MacOSX which cannot otherwise parse long opts) 
#!
#! Usage:
#!    wrapper_getopt.py shortopts longopts arg1 [arg2 ...] 
#!
#! History:
#!   17Mar14: A. De Silva, First version
#!
#!----------------------------------------------------------------------------

import getopt, sys

myArgs = str(sys.argv)

myShortOpts = sys.argv[1]
myLongOpts = sys.argv[2].split(',')
myLongOpts = [ x.replace(':','=') for x in myLongOpts ]

try:
    opts, args = getopt.gnu_getopt( sys.argv[3:], myShortOpts, myLongOpts )

except getopt.GetoptError as err:
    print str(err)
    sys.exit(64)

resultOpts = "".join(" ".join("%s %s" % tup for tup in opts)) 
resultArgs = " ".join( args )

print "%s -- %s " % (resultOpts,resultArgs)

sys.exit(0)
