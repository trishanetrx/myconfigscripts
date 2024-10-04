from tkinter import Tk, filedialog, messagebox
from PIL import Image
import os

def convert_webp_to_png(webp_file):
    png_file = os.path.splitext(webp_file)[0] + '.png'  # Change the file extension to .png
    with Image.open(webp_file) as img:
        img.save(png_file, 'PNG')
    return png_file

def select_file():
    Tk().withdraw()  # Hide the root window
    webp_file = filedialog.askopenfilename(title="Select a WebP file", filetypes=[("WebP files", "*.webp")])
    
    if webp_file:
        try:
            png_file = convert_webp_to_png(webp_file)
            messagebox.showinfo("Success", f"Converted to: {png_file}")
        except Exception as e:
            messagebox.showerror("Error", f"Failed to convert file: {e}")
    else:
        messagebox.showwarning("No Selection", "No file was selected.")

# Run the file selection dialog
if __name__ == "__main__":
    select_file()
