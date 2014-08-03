TunableSpec
===========

TunableSpec provides live tweaking of UI spec values in a running iOS app.

The goal is to make throwing up a slider easier than doing guess-and-check to choose a value. 

![Screenshot](https://github.com/kongtomorrow/TunableSpec/raw/master/Screenshot.png)

If changing a value requires restarting the app, you're never going to get as good results as if you're looking at the response live. 
Are your alpha values all multiples of 0.1? If so, this is for you.

Usage
-----
To use, add `KFTunableSpec.h` and `KFTunableSpec.m` to your project.

The only class, `KFTunableSpec`, is similar to `NSUserDefaults`.

```objc
KFTunableSpec *spec = [KFTunableSpec specNamed:@"MainSpec"];

CGFloat dur = [spec doubleForKey:@"SpringDuration"];
CGFloat damp = [spec doubleForKey:@"SpringDamping"];
```

Besides simple getters, "maintain" versions are provided for live UI updates. The maintenance block is called whenever the value changes due to being tuned. For example, with

```objc
[spec withDoubleForKey:@"LabelText" owner:self maintain:^(id owner, double doubleValue) {
 [[owner label] setText:[NSString stringWithFormat:@"%g", doubleValue]];
}];
```

the label text will live-update as you drag the tuning slider.

The values come from a JSON file that looks like this:

```
[
  {
    "sliderMaxValue" : 2,
    "key" : "SpringDuration",
    "label" : "Duration",
    "sliderValue" : 0.5756578999999999,
    "sliderMinValue" : 0
  },
  {
    "sliderMaxValue" : 1,
    "key" : "SpringDamping",
    "label" : "Damping",
    "sliderValue" : 0.5115132,
    "sliderMinValue" : 0
  }
]
```

When you've changed values in a way you want to keep, a "share" button in the UI exports a replacement JSON file to be checked into source control. 

See `KFTunableSpec.h` for full documentation, and `Spring Playground` for an example app.
