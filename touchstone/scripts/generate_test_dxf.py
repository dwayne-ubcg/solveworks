
import ezdxf
from ezdxf.enums import TextEntityAlignment

def create_test_dxf(filepath="test_countertop.dxf"):
    """
    Generates a DXF file representing a typical kitchen countertop job.
    Includes an L-shaped counter and a separate island.
    """
    doc = ezdxf.new()
    msp = doc.modelspace()

    # Define layers for clarity
    doc.layers.add("COUNTERTOPS", color=1)  # Blue
    doc.layers.add("DIMENSIONS", color=3)   # Green
    doc.layers.add("SEAMS", color=2, linetype="DASHED") # Yellow

    # Let's model it as two distinct rectangles for simplicity of parsing, as they would be cut
    # Rectangle 1 (Main leg of L): 120" x 25.5"
    l_leg1_pts = [(0, 0), (120, 0), (120, 25.5), (0, 25.5)]
    msp.add_lwpolyline(l_leg1_pts, close=True, dxfattribs={"layer": "COUNTERTOPS"})

    # Rectangle 2 (Short leg of L): 80" x 25.5"
    # Positioned to form the L-shape
    l_leg2_pts = [(120 - 25.5, 25.5), (120, 25.5), (120, 80), (120 - 25.5, 80)]
    msp.add_lwpolyline(l_leg2_pts, close=True, dxfattribs={"layer": "COUNTERTOPS"})
    
    # Add a seam line
    msp.add_line((120 - 25.5, 25.5), (120, 25.5), dxfattribs={"layer": "SEAMS"})

    # 2. Island: 60" x 36"
    island_x_start = 0
    island_y_start = 100
    island_points = [
        (island_x_start, island_y_start),
        (island_x_start + 60, island_y_start),
        (island_x_start + 60, island_y_start + 36),
        (island_x_start, island_y_start + 36),
    ]
    msp.add_lwpolyline(island_points, close=True, dxfattribs={"layer": "COUNTERTOPS"})

    # 3. Vanity Piece: 30" x 22"
    vanity_x_start = 150
    vanity_y_start = 0
    vanity_points = [
        (vanity_x_start, vanity_y_start),
        (vanity_x_start + 30, vanity_y_start),
        (vanity_x_start + 30, vanity_y_start + 22),
        (vanity_x_start, vanity_y_start + 22),
    ]
    msp.add_lwpolyline(vanity_points, close=True, dxfattribs={"layer": "COUNTERTOPS"})

    # Add some simple text labels for dimensions for visual aid
    # These won't be parsed by the script, only the polylines.
    doc.styles.add("dim_style", font="calibri.ttf")
    dim_attribs = {"layer": "DIMENSIONS", "style": "dim_style", "height": 2.5}
    
    # L-shape dims
    msp.add_text("120\"", dxfattribs=dim_attribs).set_placement((60, -5), align=TextEntityAlignment.TOP_CENTER)
    msp.add_text("25.5\"", dxfattribs=dim_attribs).set_placement((-5, 12.75), align=TextEntityAlignment.MIDDLE_RIGHT)
    msp.add_text("80\"", dxfattribs=dim_attribs).set_placement((122.5, 52.75), align=TextEntityAlignment.MIDDLE_LEFT)
    
    # Island dims
    msp.add_text("60\"", dxfattribs=dim_attribs).set_placement((island_x_start + 30, island_y_start - 5), align=TextEntityAlignment.TOP_CENTER)
    msp.add_text("36\"", dxfattribs=dim_attribs).set_placement((island_x_start - 5, island_y_start + 18), align=TextEntityAlignment.MIDDLE_RIGHT)

    # Vanity dims
    msp.add_text("30\"", dxfattribs=dim_attribs).set_placement((vanity_x_start + 15, vanity_y_start - 5), align=TextEntityAlignment.TOP_CENTER)
    msp.add_text("22\"", dxfattribs=dim_attribs).set_placement((vanity_x_start - 5, vanity_y_start + 11), align=TextEntityAlignment.MIDDLE_RIGHT)

    try:
        doc.saveas(filepath)
        print(f"Successfully created test DXF file at: {filepath}")
    except IOError:
        print(f"Could not save DXF file: {filepath}")

if __name__ == "__main__":
    create_test_dxf("/Users/macmini/clawd/solveworks-site/touchstone/scripts/test_countertop.dxf")
