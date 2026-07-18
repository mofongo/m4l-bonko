{
  "patcher": {
    "fileversion": 1,
    "appversion": {"major": 8, "minor": 6, "revision": 2, "architecture": "x64", "modernui": 1},
    "classnamespace": "box",
    "rect": [100.0, 100.0, 400.0, 300.0],
    "boxes": [
      {"box": {"id": "obj-1", "maxclass": "newobj", "text": "cycle~ 440", "numinlets": 2, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [30.0, 30.0, 70.0, 22.0]}},
      {"box": {"id": "obj-2", "maxclass": "live.dial", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [150.0, 30.0, 44.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Dup", "parameter_shortname": "Dup", "parameter_type": 0, "parameter_range": [0.0, 100.0]}}}},
      {"box": {"id": "obj-3", "maxclass": "live.dial", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [220.0, 30.0, 44.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Dup", "parameter_shortname": "Dup", "parameter_type": 0, "parameter_range": [0.0, 100.0]}}}}
    ],
    "lines": [
      {"patchline": {"source": ["obj-1", 0], "destination": ["obj-99", 0]}}
    ]
  }
}
