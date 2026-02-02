from PIL import Image, ImageDraw, ImageOps
import sys
import os

def circle_crop(image_path):
    try:
        img = Image.open(image_path).convert("RGBA")
        
        # Create a circular mask
        mask = Image.new('L', img.size, 0)
        draw = ImageDraw.Draw(mask)
        
        # Draw a white circle on the mask
        # We assume the important part of the logo is centered and circular
        width, height = img.size
        # Leave a tiny margin to avoid black edges if possible, or crop tightly
        draw.ellipse((0, 0, width, height), fill=255)
        
        # Apply the mask to the image
        output = ImageOps.fit(img, mask.size, centering=(0.5, 0.5))
        output.putalpha(mask)
        
        # Save overwriting the original or a new file
        output.save(image_path, "PNG")
        print(f"Successfully processed {image_path}")
        
    except Exception as e:
        print(f"Error processing image: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        circle_crop(sys.argv[1])
    else:
        print("Please provide an image path.")
