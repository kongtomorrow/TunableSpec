TunableSpec
===========

TunableSpec provides live tweaking of UI specification values in a running app.

Currently iOS only, and I mostly use it on the iPad.

The goal is to make it easier to use a slider to pick a value than it is to do guess-and-check. 
If changing a value requires restarting the app, you're never going to get as good results as if you're looking at the response live. 
Are your alpha values all multiples of 0.1? If so, this is for you.

From the source code perspective it's similar to NSUserDefaults, but the values are backed by a JSON file. It's able to display UI for tuning the values, and a share button exports a new JSON file to be checked back into source control.
  
See TunableSpec.h for documentation, and TunerDriver for an example app.

