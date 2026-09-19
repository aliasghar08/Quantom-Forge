import sys
import json
import base64
import webbrowser

def get_options():
    """Return the options for the Avogadro 2 Command Plugin."""
    options = {
        'userOptions': {},
        'menuPath': 'Extensions|Quantom Forge',
        'identifier': 'QuantomForgeBridge',
        'name': 'Export to Quantom Forge Web',
        'description': 'Export the current molecule directly into the Quantom Forge web app.',
        'inputFormat': 'xyz' # Request the molecule in XYZ format
    }
    print(json.dumps(options))

def run_command():
    """Execute the command: read XYZ, base64 encode, open URL."""
    # Read input from Avogadro
    input_data = sys.stdin.read()
    
    if not input_data:
        sys.stderr.write("No input data received from Avogadro.\\n")
        return

    try:
        data = json.loads(input_data)
        xyz_content = data.get('xyz', '')
        
        if not xyz_content:
            sys.stderr.write("No XYZ content found in the input.\\n")
            return
            
        # Base64 encode (URL-safe)
        encoded_xyz = base64.urlsafe_b64encode(xyz_content.encode('utf-8')).decode('utf-8')
        
        # Strip padding for cleaner URL
        encoded_xyz = encoded_xyz.rstrip('=')
        
        # Build the Deep Link URL
        url = f"https://quantom-forge.web.app/?import_xyz={encoded_xyz}"
        
        # Open in default web browser
        webbrowser.open(url)
        
        # Return success to Avogadro
        print(json.dumps({'message': 'Successfully opened Quantom Forge!'}))
        
    except Exception as e:
        sys.stderr.write(f"Error processing molecule: {str(e)}\\n")
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--print-options":
        get_options()
    elif len(sys.argv) > 1 and sys.argv[1] == "--run-command":
        run_command()
    else:
        # Fallback or testing mode
        print("This script is an Avogadro 2 Command Plugin.")
        print("Install it by placing it in your Avogadro scripts/commands directory.")
