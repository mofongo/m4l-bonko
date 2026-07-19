{
  "patcher": {
    "fileversion": 1,
    "appversion": {"major": 8, "minor": 6, "revision": 2, "architecture": "x64", "modernui": 1},
    "classnamespace": "box",
    "rect": [100.0, 100.0, 700.0, 500.0],
    "openinpresentation": 1,
    "boxes": [
      {"box": {"id": "obj-1", "maxclass": "inlet", "index": 1, "comment": "envelope signal 0..1", "numinlets": 0, "numoutlets": 1, "outlettype": [""], "patching_rect": [30.0, 30.0, 30.0, 30.0]}},
      {"box": {"id": "obj-2", "maxclass": "newobj", "text": "clip~ 0. 1.", "numinlets": 3, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [30.0, 90.0, 70.0, 22.0]}},
      {"box": {"id": "obj-3", "maxclass": "newobj", "text": "live.remote~ @normalized 1", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [30.0, 300.0, 160.0, 22.0], "saved_object_attributes": {"_persistence": 1, "normalized": 1, "smoothing": 1.0}}},
      {"box": {"id": "obj-4", "maxclass": "live.text", "varname": "map_btn", "parameter_enable": 1, "mode": 1, "text": "Map", "texton": "Map", "numinlets": 1, "numoutlets": 2, "outlettype": ["", ""], "patching_rect": [250.0, 30.0, 44.0, 20.0], "presentation": 1, "presentation_rect": [0.0, 1.0, 34.0, 18.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "MapBtn", "parameter_shortname": "Map", "parameter_type": 2, "parameter_range": [0, 1], "parameter_invisible": 1}}}},
      {"box": {"id": "obj-5", "maxclass": "message", "text": "Map a parameter", "fontsize": 10.0, "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [420.0, 300.0, 150.0, 22.0], "presentation": 1, "presentation_rect": [38.0, 1.0, 88.0, 18.0]}},
      {"box": {"id": "obj-6", "maxclass": "newobj", "text": "prepend mapping", "numinlets": 1, "numoutlets": 1, "outlettype": [""], "patching_rect": [250.0, 70.0, 100.0, 22.0]}},
      {"box": {"id": "obj-7", "maxclass": "newobj", "text": "live.map @strict 1", "numinlets": 2, "numoutlets": 5, "outlettype": ["", "", "", "", ""], "patching_rect": [250.0, 150.0, 110.0, 22.0], "saved_object_attributes": {"_persistence": 1}}},
      {"box": {"id": "obj-8", "maxclass": "newobj", "text": "sel 0", "numinlets": 2, "numoutlets": 2, "outlettype": ["bang", ""], "patching_rect": [370.0, 70.0, 40.0, 22.0]}},
      {"box": {"id": "obj-9", "maxclass": "message", "text": "unmap", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [370.0, 105.0, 48.0, 22.0]}},
      {"box": {"id": "obj-10", "maxclass": "newobj", "text": "route <none>", "numinlets": 1, "numoutlets": 2, "outlettype": ["", ""], "patching_rect": [420.0, 200.0, 84.0, 22.0]}},
      {"box": {"id": "obj-11", "maxclass": "message", "text": "set Map a parameter", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [420.0, 240.0, 124.0, 22.0]}},
      {"box": {"id": "obj-12", "maxclass": "newobj", "text": "prepend set", "numinlets": 1, "numoutlets": 1, "outlettype": [""], "patching_rect": [560.0, 240.0, 74.0, 22.0]}},
      {"box": {"id": "obj-13", "maxclass": "message", "text": "id 0", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [330.0, 240.0, 34.0, 22.0]}},
      {"box": {"id": "obj-14", "maxclass": "message", "text": "set $1", "numinlets": 2, "numoutlets": 1, "outlettype": [""], "patching_rect": [250.0, 200.0, 44.0, 22.0]}},
      {"box": {"id": "obj-15", "maxclass": "newobj", "text": "fromsymbol", "numinlets": 1, "numoutlets": 1, "outlettype": [""], "patching_rect": [560.0, 200.0, 74.0, 22.0]}}
    ],
    "lines": [
      {"patchline": {"source": ["obj-1", 0], "destination": ["obj-2", 0]}},
      {"patchline": {"source": ["obj-2", 0], "destination": ["obj-3", 0]}},
      {"patchline": {"source": ["obj-4", 0], "destination": ["obj-6", 0]}},
      {"patchline": {"source": ["obj-4", 0], "destination": ["obj-8", 0]}},
      {"patchline": {"source": ["obj-6", 0], "destination": ["obj-7", 0]}},
      {"patchline": {"source": ["obj-8", 0], "destination": ["obj-9", 0]}},
      {"patchline": {"source": ["obj-9", 0], "destination": ["obj-7", 0]}},
      {"patchline": {"source": ["obj-7", 1], "destination": ["obj-3", 1]}},
      {"patchline": {"source": ["obj-7", 2], "destination": ["obj-10", 0]}},
      {"patchline": {"source": ["obj-7", 3], "destination": ["obj-14", 0]}},
      {"patchline": {"source": ["obj-14", 0], "destination": ["obj-4", 0]}},
      {"patchline": {"source": ["obj-10", 0], "destination": ["obj-11", 0]}},
      {"patchline": {"source": ["obj-10", 0], "destination": ["obj-13", 0]}},
      {"patchline": {"source": ["obj-10", 1], "destination": ["obj-15", 0]}},
      {"patchline": {"source": ["obj-15", 0], "destination": ["obj-12", 0]}},
      {"patchline": {"source": ["obj-11", 0], "destination": ["obj-5", 0]}},
      {"patchline": {"source": ["obj-13", 0], "destination": ["obj-3", 1]}},
      {"patchline": {"source": ["obj-12", 0], "destination": ["obj-5", 0]}}
    ]
  }
}
