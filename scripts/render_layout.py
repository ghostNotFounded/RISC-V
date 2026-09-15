import pya
import os

in_gds = in_gds
in_lyp = in_lyp
out_png = out_png

os.makedirs(os.path.dirname(os.path.abspath(out_png)), exist_ok=True)

app = pya.Application.instance()
win = app.main_window()
win.load_layout(in_gds, 0)
view = win.current_view()
view.load_layer_props(in_lyp)
view.max_hier()
view.zoom_fit()
view.save_image(out_png, 2048, 2048)
print(f"Successfully generated layout image at {out_png}")
app.exit(0)
