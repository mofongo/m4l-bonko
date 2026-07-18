{
  "patcher": {
    "fileversion": 1,
    "appversion": {"major": 8, "minor": 6, "revision": 2, "architecture": "x64", "modernui": 1},
    "classnamespace": "box",
    "rect": [100.0, 100.0, 700.0, 500.0],
    "openinpresentation": 1,
    "boxes": [
      {"box": {"id": "obj-1", "maxclass": "inlet", "index": 1, "comment": "audio in (signal)", "numinlets": 0, "numoutlets": 1, "outlettype": [""], "patching_rect": [30.0, 30.0, 30.0, 30.0]}},
      {"box": {"id": "obj-2", "maxclass": "newobj", "text": "svf~ 3250. 0.707", "numinlets": 3, "numoutlets": 4, "outlettype": ["signal", "signal", "signal", "signal"], "patching_rect": [30.0, 90.0, 110.0, 22.0]}},
      {"box": {"id": "obj-3", "maxclass": "newobj", "text": "abs~", "numinlets": 1, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [55.0, 130.0, 40.0, 22.0]}},
      {"box": {"id": "obj-4", "maxclass": "newobj", "text": "slide~ 10. 2205.", "numinlets": 3, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [55.0, 170.0, 100.0, 22.0]}},
      {"box": {"id": "obj-5", "maxclass": "newobj", "text": ">~ 0.05", "numinlets": 2, "numoutlets": 1, "outlettype": ["signal"], "patching_rect": [55.0, 250.0, 60.0, 22.0]}},
      {"box": {"id": "obj-6", "maxclass": "newobj", "text": "edge~", "numinlets": 1, "numoutlets": 2, "outlettype": ["bang", "bang"], "patching_rect": [55.0, 290.0, 46.0, 22.0]}},
      {"box": {"id": "obj-7", "maxclass": "newobj", "text": "onebang", "numinlets": 2, "numoutlets": 2, "outlettype": ["bang", "bang"], "patching_rect": [55.0, 330.0, 60.0, 22.0]}},
      {"box": {"id": "obj-8", "maxclass": "newobj", "text": "t b b b", "numinlets": 1, "numoutlets": 3, "outlettype": ["bang", "bang", "bang"], "patching_rect": [55.0, 370.0, 50.0, 22.0]}},
      {"box": {"id": "obj-9", "maxclass": "newobj", "text": "delay 60", "numinlets": 2, "numoutlets": 1, "outlettype": ["bang"], "patching_rect": [110.0, 410.0, 60.0, 22.0]}},
      {"box": {"id": "obj-10", "maxclass": "outlet", "index": 1, "comment": "bang per transient", "numinlets": 1, "numoutlets": 0, "patching_rect": [55.0, 455.0, 30.0, 30.0]}},
      {"box": {"id": "obj-11", "maxclass": "newobj", "text": "loadbang", "numinlets": 1, "numoutlets": 1, "outlettype": ["bang"], "patching_rect": [200.0, 290.0, 60.0, 22.0]}},
      {"box": {"id": "obj-12", "maxclass": "live.dial", "varname": "focus", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [300.0, 60.0, 44.0, 48.0], "presentation": 1, "presentation_rect": [64.0, 22.0, 44.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Focus", "parameter_shortname": "Focus", "parameter_type": 0, "parameter_unitstyle": 3, "parameter_range": [200.0, 8000.0], "parameter_exponent": 3.0, "parameter_initial_enable": 1, "parameter_initial": [3250.0]}}}},
      {"box": {"id": "obj-13", "maxclass": "live.dial", "varname": "sens", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [380.0, 60.0, 44.0, 48.0], "presentation": 1, "presentation_rect": [10.0, 106.0, 44.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Sens", "parameter_shortname": "Sens", "parameter_type": 0, "parameter_unitstyle": 5, "parameter_range": [0.0, 100.0], "parameter_initial_enable": 1, "parameter_initial": [50.0]}}}},
      {"box": {"id": "obj-14", "maxclass": "newobj", "text": "expr 0.5*pow(0.001\\,$f1*0.01)", "numinlets": 1, "numoutlets": 1, "outlettype": ["float"], "patching_rect": [380.0, 130.0, 180.0, 22.0]}},
      {"box": {"id": "obj-15", "maxclass": "live.dial", "varname": "retrig", "parameter_enable": 1, "numinlets": 1, "numoutlets": 2, "outlettype": ["", "float"], "patching_rect": [460.0, 60.0, 44.0, 48.0], "presentation": 1, "presentation_rect": [64.0, 106.0, 44.0, 48.0], "saved_attribute_attributes": {"valueof": {"parameter_longname": "Retrig", "parameter_shortname": "Retrig", "parameter_type": 0, "parameter_unitstyle": 2, "parameter_range": [20.0, 500.0], "parameter_initial_enable": 1, "parameter_initial": [60.0]}}}},
      {"box": {"id": "obj-16", "maxclass": "meter~", "numinlets": 1, "numoutlets": 1, "outlettype": ["float"], "patching_rect": [200.0, 170.0, 12.0, 80.0], "presentation": 1, "presentation_rect": [6.0, 24.0, 10.0, 76.0]}},
      {"box": {"id": "obj-17", "maxclass": "button", "numinlets": 1, "numoutlets": 1, "outlettype": ["bang"], "patching_rect": [130.0, 410.0, 20.0, 20.0], "presentation": 1, "presentation_rect": [40.0, 24.0, 16.0, 16.0]}},
      {"box": {"id": "obj-18", "maxclass": "comment", "text": "BONKO DETECT", "numinlets": 1, "numoutlets": 0, "patching_rect": [300.0, 20.0, 120.0, 20.0], "presentation": 1, "presentation_rect": [4.0, 2.0, 112.0, 18.0]}}
    ],
    "lines": [
      {"patchline": {"source": ["obj-1", 0], "destination": ["obj-2", 0]}},
      {"patchline": {"source": ["obj-12", 0], "destination": ["obj-2", 1]}},
      {"patchline": {"source": ["obj-2", 1], "destination": ["obj-3", 0]}},
      {"patchline": {"source": ["obj-3", 0], "destination": ["obj-4", 0]}},
      {"patchline": {"source": ["obj-4", 0], "destination": ["obj-5", 0]}},
      {"patchline": {"source": ["obj-4", 0], "destination": ["obj-16", 0]}},
      {"patchline": {"source": ["obj-13", 0], "destination": ["obj-14", 0]}},
      {"patchline": {"source": ["obj-14", 0], "destination": ["obj-5", 1]}},
      {"patchline": {"source": ["obj-5", 0], "destination": ["obj-6", 0]}},
      {"patchline": {"source": ["obj-6", 0], "destination": ["obj-7", 0]}},
      {"patchline": {"source": ["obj-11", 0], "destination": ["obj-7", 1]}},
      {"patchline": {"source": ["obj-7", 0], "destination": ["obj-8", 0]}},
      {"patchline": {"source": ["obj-8", 0], "destination": ["obj-10", 0]}},
      {"patchline": {"source": ["obj-8", 1], "destination": ["obj-9", 0]}},
      {"patchline": {"source": ["obj-8", 2], "destination": ["obj-17", 0]}},
      {"patchline": {"source": ["obj-15", 0], "destination": ["obj-9", 1]}},
      {"patchline": {"source": ["obj-9", 0], "destination": ["obj-7", 1]}}
    ]
  }
}
