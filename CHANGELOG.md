## CHANGELOG: CSV Exporter Excel VBA Add-In

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](http://semver.org/spec/v2.0.0.html).


### [Unreleased]

...


### [1.1.0] - 2019-01-08

#### Added

 * New information box on the form indicates the sheet and range of
   cells currently set to be exported
 * New warning added, if the separator appears in the data to be exported;
   this should minimize accidental generation of files that cannot be
   used subsequently, due to the excess separator characters

#### Changed

 * UserForm now reappears in its prior location when closed
   and re-opened, instead of always reappearing in the center
   of the Excel window.
 * Selection of multiple areas now results in an "<invalid selection>"
   message in the new information box; and, greying out of the 'Export'
   button instead of a warning message after clicking 'Export'
 * Selection of entire rows/columns now sets for export the intersection
   of the selection and the UsedRange of the worksheet. Selection of an
   entire row/column outside the UsedRange of the worksheet gives an
   "<invalid selection>" message in the new information box and disables
   the 'Export' button

#### Fixed

 * Userform now disappears when a chart-sheet is selected, and reappears
   when a worksheet is re-selected. Userform will silently refuse to open
   if triggered when a chart-sheet is active
 * Error handling added around folder selection and output file opening
   for write/append

### [1.0.0] - 2016-01-30

*Initial release*

#### Features
 * Folder selection works
 * Name, number format, and separator entry work
 * Append vs overwrite works
 * Modeless form retains folder/filename/format/separator/etc. within a given Excel instance

#### Limitations
 * Exports only a single contiguous range at a time

#### Internals
 * Modest validity checking implemented for filename
   * Red text and disabled `Export` button on invalid filename
 * No validity checking implemented for number format
 * Disabled `Export` button if number format or separator are empty
