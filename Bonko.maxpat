{
  "patcher": {
    "fileversion": 1,
    "appversion": {"major": 8, "minor": 6, "revision": 2, "architecture": "x64", "modernui": 1},
    "classnamespace": "box",
    "rect": [100.0, 100.0, 900.0, 400.0],
    "openinpresentation": 1,
    "boxes": [
      {"box": {"id": "obj-1", "maxclass": "newobj", "text": "plugin~", "numinlets": 1, "numoutlets": 2, "outlettype": ["signal", "signal"], "patching_rect": [30.0, 30.0, 60.0, 22.0]}},
      {"box": {"id": "obj-2", "maxclass": "newobj", "text": "plugout~", "numinlets": 2, "numoutlets": 2, "outlettype": ["signal", "signal"], "patching_rect": [30.0, 90.0, 66.0, 22.0]}},
      {"box": {"id": "obj-3", "maxclass": "newobj", "text": "+~", "numinlets": 2, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [150.0, 90.0, 34.0, 22.0]}},
      {"box": {"id": "obj-4", "maxclass": "newobj", "text": "*~ 0.5", "numinlets": 2, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [150.0, 130.0, 48.0, 22.0]}},
      {"box": {"id": "obj-5", "maxclass": "bpatcher", "name": "bonko.detector.maxpat", "numinlets": 1, "numoutlets": 1, "outlettype": [""], "patching_rect": [150.0, 170.0, 160.0, 100.0], "presentation": 1, "presentation_rect": [4.0, 4.0, 120.0, 161.0], "viewvisibility": 1}},
      {"box": {"id": "obj-6", "maxclass": "newobj", "text": "s ---trig", "numinlets": 1, "numoutlets": 0, "patching_rect": [150.0, 290.0, 60.0, 22.0]}},
      {"box": {"id": "obj-7", "maxclass": "bpatcher", "name": "bonko.slot.maxpat", "numinlets": 0, "numoutlets": 0, "patching_rect": [360.0, 30.0, 120.0, 80.0], "presentation": 1, "presentation_rect": [128.0, 4.0, 138.0, 161.0], "viewvisibility": 1}},
      {"box": {"id": "obj-8", "maxclass": "bpatcher", "name": "bonko.slot.maxpat", "numinlets": 0, "numoutlets": 0, "patching_rect": [360.0, 130.0, 120.0, 80.0], "presentation": 1, "presentation_rect": [270.0, 4.0, 138.0, 161.0], "viewvisibility": 1}},
      {"box": {"id": "obj-9", "maxclass": "bpatcher", "name": "bonko.slot.maxpat", "numinlets": 0, "numoutlets": 0, "patching_rect": [360.0, 230.0, 120.0, 80.0], "presentation": 1, "presentation_rect": [412.0, 4.0, 138.0, 161.0], "viewvisibility": 1}},
      {"box": {"id": "obj-10", "maxclass": "bpatcher", "name": "bonko.slot.maxpat", "numinlets": 0, "numoutlets": 0, "patching_rect": [360.0, 330.0, 120.0, 80.0], "presentation": 1, "presentation_rect": [554.0, 4.0, 138.0, 161.0], "viewvisibility": 1}}
    ],
    "lines": [
      {"patchline": {"source": ["obj-1", 0], "destination": ["obj-2", 0]}},
      {"patchline": {"source": ["obj-1", 1], "destination": ["obj-2", 1]}},
      {"patchline": {"source": ["obj-1", 0], "destination": ["obj-3", 0]}},
      {"patchline": {"source": ["obj-1", 1], "destination": ["obj-3", 1]}},
      {"patchline": {"source": ["obj-3", 0], "destination": ["obj-4", 0]}},
      {"patchline": {"source": ["obj-4", 0], "destination": ["obj-5", 0]}},
      {"patchline": {"source": ["obj-5", 0], "destination": ["obj-6", 0]}}
    ]
  }
}
