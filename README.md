TOML is an Objective-C parser for the [TOML markup language](https://github.com/mojombo/toml). 

Installation
=

Add the TOMLParser class and the ISO8601DateFormatter to your Xcode project. TOMLParser requires ARC.

Usage
=

Just call `+[TOMLParser dictionaryWithContentsOfString:error:]` with a TOML string and it'll spit out a dictionary, maybe.

Does it work?
=

Probably not.

Compatibility
=

Works with the example.toml file as of mojombo/toml@a7e7e9e335c34131af3c86569b7d674b8d9412e1. Included is a unit test bundle which verifies it.

License
=

MIT license. Do what you want and attribute.

Copyright (c) 2013 Steve Streza

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.