#! /bin/sh

codesign --options runtime -f -s "Peter Sugihara" --entitlements "server.entitlements" "server"
