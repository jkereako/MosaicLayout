# MosaicLayout
A Swift version of Bryce Redd's RFQuiltLayout

# Off-by-1 error
Although you may not notice, this layout contains an off-by-1 error. The culprit *may* be the `+1` added to 2 of the `for` loops. However, removing the `+1` breaks the entire layout.

The easiest work around is to add an extra object to the datasource.
