
import json
import os
from dxf_estimator import generate_quote

def run_test():
    """
    Runs a test of the DXF estimator with a sample file and material.
    """
    # Define paths relative to this script's location
    script_dir = os.path.dirname(os.path.abspath(__file__))
    dxf_file = os.path.join(script_dir, "test_countertop.dxf")
    materials_db = os.path.join(script_dir, "material_prices.json")
    
    # Choose a material for the test
    test_material = "Luna"

    print(f"Running quote generation for: {os.path.basename(dxf_file)}")
    print(f"Using material: {test_material}")
    print("-" * 30)

    # Check if the DXF file exists
    if not os.path.exists(dxf_file):
        print(f"Error: Test DXF file not found at {dxf_file}")
        print("Please run generate_test_dxf.py first to create it.")
        return

    # Generate the quote
    quote_data = generate_quote(dxf_file, test_material, materials_db)

    # Pretty-print the JSON output
    print("Generated Quote:")
    print(json.dumps(quote_data, indent=2))
    
    print("-" * 30)
    print("Test complete.")

if __name__ == "__main__":
    run_test()
