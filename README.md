[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENSE.md) [![Haxelib Version](https://img.shields.io/github/tag/openfl/lime-samples.svg?style=flat&label=haxelib)](http://lib.haxe.org/p/lime-samples)

Lime Samples
==============

A collection of sample projects illustrating different [Lime](https://lime.openfl.org/) features.


Installation
------------

    haxelib install lime
    haxelib run lime setup
    
The `lime-samples` library will be installed automatically. If you need to install it alone, you can use the following command:

    haxelib install lime-samples


### Listing Samples

You can browse the project directory, but it is generally simpler to use the following command to list available Lime samples:

    lime create


### Creating Samples

Once you find a sample you would like to create, you can generate a copy using the "create" command:

    lime create HelloWorld

This creates a copy in the current directory, but you can also specify an output directory if you prefer:

    lime create HelloWorld LimeTest


Development Builds
------------------

Clone the lime-samples repository:

    git clone https://github.com/openfl/lime-samples


Tell haxelib where your development copy of lime-samples is installed:

    haxelib dev lime-samples lime-samples


To return to release builds:

    haxelib dev lime-samples

