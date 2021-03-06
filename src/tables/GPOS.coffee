r = require 'restructure'
{ScriptList, FeatureList, LookupList, Coverage, ClassDef, Device} = require './opentype'

ValueFormat = new r.Bitfield r.uint16, [
  'xPlacement', 'yPlacement',
  'xAdvance', 'yAdvance',
  'xPlaDevice', 'yPlaDevice',
  'xAdvDevice', 'yAdvDevice'
]

class ValueRecord
  constructor: (@key = 'valueFormat') ->
    @size = undefined
    
  types = 
    xPlacement: r.int16
    yPlacement: r.int16
    xAdvance:   r.int16
    yAdvance:   r.int16
    xPlaDevice: new r.Pointer(r.uint16, Device)
    yPlaDevice: new r.Pointer(r.uint16, Device)
    xAdvDevice: new r.Pointer(r.uint16, Device)
    yAdvDevice: new r.Pointer(r.uint16, Device)
    
  decode: (stream, parent) ->
    struct = parent
    while not struct[@key] and struct.parent
      struct = struct.parent
      
    return unless struct[@key]
    
    fields = {}
    for key, included of struct[@key] when included
      type = types[key]
      if type instanceof r.Pointer
        type.relativeTo = -> struct._startOffset
        
      fields[key] = type
      
    return new r.Struct(fields).decode(stream, parent)
  
PairValueRecord = new r.Struct
  secondGlyph:    r.uint16
  value1:         new ValueRecord('valueFormat1')
  value2:         new ValueRecord('valueFormat2')
  
PairSet = new r.Array(PairValueRecord, r.uint16)

Class2Record = new r.Struct
  value1: new ValueRecord('valueFormat1')
  value2: new ValueRecord('valueFormat2')
  
Anchor = new r.VersionedStruct r.uint16,
  1: # Design units only
    xCoordinate:    r.int16
    yCoordinate:    r.int16
    
  2: # Design units plus contour point
    xCoordinate:    r.int16
    yCoordinate:    r.int16
    anchorPoint:    r.uint16
    
  3: # Design units plus Device tables
    xCoordinate:    r.int16
    yCoordinate:    r.int16
    xDeviceTable:   new r.Pointer(r.uint16, Device)
    yDeviceTable:   new r.Pointer(r.uint16, Device)
  
EntryExitRecord = new r.Struct
  entryAnchor:    new r.Pointer(r.uint16, Anchor)
  exitAnchor:     new r.Pointer(r.uint16, Anchor)
  
MarkRecord = new r.Struct
  class:      r.uint16
  markAnchor: new r.Pointer(r.uint16, Anchor, type: 'parent')
  
MarkArray = new r.Array(MarkRecord, r.uint16)
  
BaseRecord  = new r.Array(new r.Pointer(r.uint16, Anchor), -> @parent.classCount)
BaseArray   = new r.Array(BaseRecord, r.uint16)

ComponentRecord = new r.Array(new r.Pointer(r.uint16, Anchor), -> @parent.parent.classCount)
LigatureAttach  = new r.Array(ComponentRecord, r.uint16)
LigatureArray   = new r.Array(new r.Pointer(r.uint16, LigatureAttach), r.uint16)

GPOSLookup = new r.VersionedStruct 'lookupType',
  1: new r.VersionedStruct r.uint16, # Single Adjustment
    1: # Single positioning value
      coverage:       new r.Pointer(r.uint16, Coverage)
      valueFormat:    ValueFormat
      value:          new ValueRecord
    2:
      coverage:       new r.Pointer(r.uint16, Coverage)
      valueFormat:    ValueFormat
      valueCount:     r.uint16
      values:         new r.Array(new ValueRecord, 'valueCou')
  
  2: new r.VersionedStruct r.uint16, # Pair Adjustment Positioning
    1: # Adjustments for glyph pairs
      coverage:       new r.Pointer(r.uint16, Coverage)
      valueFormat1:   ValueFormat
      valueFormat2:   ValueFormat
      pairSetCount:   r.uint16
      pairSets:       new r.Array(new r.Pointer(r.uint16, PairSet), 'pairSetCount')
      
    2: # Class pair adjustment
      coverage:       new r.Pointer(r.uint16, Coverage)
      valueFormat1:   ValueFormat
      valueFormat2:   ValueFormat
      classDef1:      new r.Pointer(r.uint16, ClassDef)
      classDef2:      new r.Pointer(r.uint16, ClassDef)
      class1Count:    r.uint16
      class2Count:    r.uint16
      classRecords:  new r.Array(new r.Array(Class2Record, 'class2Count'), 'class1Count')
  
  3: # Cursive Attachment Positioning
    format:             r.uint16
    coverage:           new r.Pointer(r.uint16, Coverage)
    entryExitCount:     r.uint16
    entryExitRecords:   new r.Array(EntryExitRecord, 'entryExitCount')
    
  4: # MarkToBase Attachment Positioning
    format:             r.uint16
    markCoverage:       new r.Pointer(r.uint16, Coverage)
    baseCoverage:       new r.Pointer(r.uint16, Coverage)
    classCount:         r.uint16
    markArray:          new r.Pointer(r.uint16, MarkArray)
    baseArray:          new r.Pointer(r.uint16, BaseArray)
    
  5: # MarkToLigature Attachment Positioning
    format:             r.uint16
    markCoverage:       new r.Pointer(r.uint16, Coverage)
    ligatureCoverage:   new r.Pointer(r.uint16, Coverage)
    classCount:         r.uint16
    markArray:          new r.Pointer(r.uint16, MarkArray)
    ligatureArray:      new r.Pointer(r.uint16, LigatureArray)
    
  6: # MarkToMark Attachment Positioning
    format:             r.uint16
    mark1Coverage:      new r.Pointer(r.uint16, Coverage)
    mark2Coverage:      new r.Pointer(r.uint16, Coverage)
    classCount:         r.uint16
    mark1Array:         new r.Pointer(r.uint16, MarkArray)
    mark2Array:         new r.Pointer(r.uint16, BaseArray)
    
  7: 
    format: r.uint16
    
  8: 
    format: r.uint16
    
  9: 
    format: r.uint16
  
module.exports = new r.Struct
  version:        r.int32
  scriptList:     new r.Pointer(r.uint16, ScriptList)
  featureList:    new r.Pointer(r.uint16, FeatureList)
  lookupList:     new r.Pointer(r.uint16, new LookupList(GPOSLookup))
  
# export GPOSLookup for JSTF table
module.exports.GPOSLookup = GPOSLookup
