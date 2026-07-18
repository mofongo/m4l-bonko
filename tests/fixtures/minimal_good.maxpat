{
  "patcher": {
    "fileversion": 1,
    "appversion": {"major": 8, "minor": 6, "revision": 2, "architecture": "x64", "modernui": 1},
    "classnamespace": "box",
    "rect": [100.0, 100.0, 400.0, 300.0],
    "boxes": [
      {"box": {"id": "obj-1", "maxclass": "newobj", "text": "cycle~ 440", "numinlets": 2, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [30.0, 30.0, 70.0, 22.0]}},
      {"box": {"id": "obj-2", "maxclass": "newobj", "text": "*~ 0.1", "numinlets": 2, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [30.0, 70.0, 50.0, 22.0]}}
    ],
    "lines": [
      {"patchline": {"source": ["obj-1", 0], "destination": ["obj-2", 0]}}
    ]
  }
}
