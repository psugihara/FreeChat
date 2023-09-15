#! /bin/sh

codesign --options runtime -f -s "Peter Sugihara" --entitlements "freechat-server.entitlements" "freechat-server"
