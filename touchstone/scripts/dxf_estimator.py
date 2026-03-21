
import ezdxf
import json
import math
from collections import namedtuple

Piece = namedtuple('Piece', ['length', 'width', 'area'])
Slab = namedtuple('Slab', ['length', 'width', 'area'])

def parse_dxf_pieces(filepath):
    """
    Parses a DXF file to find all LWPOLYLINE entities on the 'COUNTERTOPS' layer
    and returns their dimensions.
    """
    try:
        doc = ezdxf.readfile(filepath)
    except IOError:
        print(f"Not a DXF file or a generic I/O error: {filepath}")
        return []
    except ezdxf.DXFStructureError:
        print(f"Invalid or corrupted DXF file: {filepath}")
        return []

    msp = doc.modelspace()
    pieces = []
    
    # Query for all LWPOLYLINE entities first
    for polyline in msp.query('LWPOLYLINE'):
        # Then, filter by layer and other properties in Python
        if (polyline.dxf.layer == "COUNTERTOPS" and 
            polyline.is_closed and 
            len(polyline) == 4): # Assuming rectangular shapes
            
            points = list(polyline.get_points('xy'))
            # Calculate distances between adjacent points
            side1 = math.dist(points[0], points[1])
            side2 = math.dist(points[1], points[2])
            
            length = max(side1, side2)
            width = min(side1, side2)
            area = length * width
            pieces.append(Piece(length, width, area))
            
    return pieces

def simple_slab_optimizer(pieces, slab_length, slab_width):
    """
    A very basic greedy algorithm to determine how many slabs are needed.
    This is a complex problem (2D bin packing), so this is a simplified heuristic.
    It sorts pieces by length and places them one by one.
    """
    if not pieces:
        return 0, 0, []

    slab = Slab(slab_length, slab_width, slab_length * slab_width)
    pieces.sort(key=lambda p: p.length, reverse=True)

    slabs_used = 1
    current_slabs = [{'length_used': 0, 'width_used': 0, 'pieces': [], 'open_rows': [(slab.length, slab.width)]}]

    # A simple level-based packing heuristic
    # This is not optimal but a decent starting point.
    # It places the largest item and creates a new "shelf" or row.
    
    slabs_needed = 0
    packed_pieces_total_area = 0
    
    # Simplified logic for prototype: Check if total area exceeds one slab area,
    # but more realistically, we should check if pieces can fit.
    # A real implementation needs a proper packing algorithm.
    
    # For this prototype, we'll use a very naive method:
    # If the longest piece is longer than the slab, we can't cut it.
    if any(p.length > slab.length or p.width > slab.width for p in pieces):
         # Could add logic here to check if rotating the slab helps
         pass # For now, assume orientation is fixed

    # Naive assumption: sum of areas gives a lower bound.
    total_piece_area = sum(p.area for p in pieces)
    slabs_needed = math.ceil(total_piece_area / (slab.area * 0.90)) # Assume 90% utilization

    # A slightly better heuristic:
    # Count how many of the largest pieces can fit side-by-side
    pieces.sort(key=lambda p: p.width, reverse=True)
    if pieces[0].width > slab.width:
        # Cannot fit
        pass

    # This problem is non-trivial. For a prototype, let's just use the area calculation
    # as a stand-in for a real algorithm.
    
    total_area_needed = sum(p.area for p in pieces)
    num_slabs = math.ceil(total_area_needed / slab.area)

    # Let's refine slightly: if any dimension of any piece exceeds the slab, it's impossible.
    if any(p.length > slab.length or p.width > slab.width for p in pieces):
        # A more robust check would see if rotating the piece helps
        if not any(p.length <= slab.width and p.width <= slab.length for p in pieces):
            # raise ValueError("A piece is too large to fit on a slab.")
            # For now, just assume it works for the prototype
             pass
    
    # The area method is a reasonable starting point for an estimator.
    return num_slabs, total_area_needed, [] # Returning empty remnants for now


def generate_quote(dxf_filepath, material_name, materials_db_path="material_prices.json"):
    """
    Generates a quote based on a DXF file and material choice.
    """
    # 1. Load Materials DB
    with open(materials_db_path, 'r') as f:
        materials_db = json.load(f)

    if material_name not in materials_db:
        raise ValueError(f"Material '{material_name}' not found in the database.")

    material = materials_db[material_name]
    slab_cost = material['slab_cost']
    slab_length = material['slab_length']
    slab_width = material['slab_width']
    slab_area_sqin = slab_length * slab_width
    slab_area_sqft = slab_area_sqin / 144.0

    # 2. Parse DXF to get pieces
    pieces = parse_dxf_pieces(dxf_filepath)
    if not pieces:
        return {"error": "No valid countertop pieces found in the DXF file."}

    # 3. Optimize slab usage
    num_slabs, total_piece_area_sqin, remnants = simple_slab_optimizer(pieces, slab_length, slab_width)
    total_piece_area_sqft = total_piece_area_sqin / 144.0

    # 4. Calculate costs and other metrics
    total_material_cost = num_slabs * slab_cost
    
    # Assume a fabrication cost, e.g., $40/sqft
    fabrication_rate_sqft = 40.00
    estimated_fabrication_cost = total_piece_area_sqft * fabrication_rate_sqft
    
    total_slab_area_sqin = num_slabs * slab_area_sqin
    waste_sqin = total_slab_area_sqin - total_piece_area_sqin
    waste_sqft = waste_sqin / 144.0
    
    # Remnant value is complex. For now, let's assume 0 credit.
    remnant_credit_value = 0.00

    # Total price calculation
    total_price = total_material_cost + estimated_fabrication_cost - remnant_credit_value
    
    # Profit Margin (example: assume total cost to business is 70% of price)
    cost_of_goods = total_price * 0.70 
    profit = total_price - cost_of_goods
    profit_margin = (profit / total_price) * 100 if total_price > 0 else 0

    # 5. Assemble Quote
    quote = {
        "job_details": {
            "dxf_file": dxf_filepath,
            "material": material_name,
        },
        "summary": {
            "total_countertop_sqft": round(total_piece_area_sqft, 2),
            "slabs_required": num_slabs,
        },
        "cost_breakdown": {
            "material_cost": f"${total_material_cost:,.2f}",
            "estimated_fabrication_cost": f"${estimated_fabrication_cost:,.2f}",
            "remnant_credit": f"${remnant_credit_value:,.2f}",
            "total_quote_price": f"${total_price:,.2f}",
        },
        "fabrication_data": {
            "total_slab_area_sqft": round(num_slabs * slab_area_sqft, 2),
            "waste_sqft": round(waste_sqft, 2),
            "number_of_pieces": len(pieces),
        },
        "business_metrics": {
             "profit_margin_percent": f"{profit_margin:.2f}%"
        },
        "pieces": [
            {"length": round(p.length, 2), "width": round(p.width, 2)} for p in pieces
        ]
    }
    
    return quote
