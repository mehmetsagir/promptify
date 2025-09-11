#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw
import math

def create_icon(size):
    # Create a new image with transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Create purple gradient background similar to the reference image
    for y in range(size):
        ratio = y / size
        # Purple gradient: darker purple to lighter purple
        r = int(76 * (1 - ratio) + 110 * ratio)   # 76->110
        g = int(84 * (1 - ratio) + 115 * ratio)   # 84->115
        b = int(200 * (1 - ratio) + 230 * ratio)  # 200->230
        color = (r, g, b, 255)
        draw.line([(0, y), (size, y)], fill=color)
    
    # Add rounded rectangle mask - modern iOS style
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    corner_radius = size // 8  # iOS-style corner radius
    mask_draw.rounded_rectangle([0, 0, size, size], radius=corner_radius, fill=255)
    
    # Apply mask
    img.putalpha(mask)
    
    # Draw feather (quill pen) - main element
    center_x, center_y = size // 2, size // 2
    feather_height = size // 1.8  # Make it prominent
    feather_width = feather_height // 3
    
    # Feather positioning - slightly to the left and rotated
    feather_x = center_x - size // 8
    feather_y = center_y
    
    # Draw feather shaft (main stem)
    shaft_start_x = feather_x
    shaft_start_y = feather_y + feather_height // 2
    shaft_end_x = feather_x + feather_height // 8
    shaft_end_y = feather_y - feather_height // 2
    
    shaft_width = max(2, size // 40)
    draw.line([(shaft_start_x, shaft_start_y), (shaft_end_x, shaft_end_y)], 
              fill=(255, 255, 255, 255), width=shaft_width)
    
    # Draw feather vane (the fluffy part) - left side
    vane_points_left = []
    for i in range(8):  # Number of points on left side
        progress = i / 7.0
        offset_y = feather_y - feather_height // 2 + (feather_height * progress)
        
        # Create curved outline for left side of feather
        curve_offset = int(feather_width * math.sin(progress * math.pi) * 0.7)
        point_x = feather_x - curve_offset
        point_y = offset_y
        vane_points_left.append((point_x, point_y))
    
    # Draw feather vane (the fluffy part) - right side
    vane_points_right = []
    for i in range(8):  # Number of points on right side
        progress = i / 7.0
        offset_y = feather_y - feather_height // 2 + (feather_height * progress)
        
        # Create curved outline for right side of feather (smaller)
        curve_offset = int(feather_width * math.sin(progress * math.pi) * 0.4)
        point_x = feather_x + curve_offset + feather_height // 12
        point_y = offset_y
        vane_points_right.append((point_x, point_y))
    
    # Create complete feather outline
    feather_points = vane_points_left + list(reversed(vane_points_right))
    
    # Draw filled feather
    draw.polygon(feather_points, fill=(255, 255, 255, 255))
    
    # Add feather details (barbs)
    for i in range(1, 7):
        progress = i / 7.0
        detail_y = feather_y - feather_height // 2 + (feather_height * progress * 0.8)
        
        # Left side barbs
        left_start_x = feather_x
        left_end_x = feather_x - int(feather_width * math.sin(progress * math.pi) * 0.5)
        draw.line([(left_start_x, detail_y), (left_end_x, detail_y)], 
                  fill=(76, 84, 200, 180), width=max(1, size // 80))
        
        # Right side barbs (shorter)
        right_start_x = feather_x + feather_height // 24
        right_end_x = feather_x + int(feather_width * math.sin(progress * math.pi) * 0.3) + feather_height // 12
        draw.line([(right_start_x, detail_y), (right_end_x, detail_y)], 
                  fill=(76, 84, 200, 180), width=max(1, size // 80))
    
    # Draw small decorative dots (magic particles) on the right side
    dot_positions = [
        (center_x + size // 4, center_y - size // 12),
        (center_x + size // 6, center_y + size // 8),
        (center_x + size // 3, center_y + size // 16)
    ]
    
    for i, (dot_x, dot_y) in enumerate(dot_positions):
        # Different sizes for visual hierarchy
        if i == 0:  # Largest dot
            dot_size = max(2, size // 25)
        elif i == 1:  # Medium dot
            dot_size = max(1, size // 35)
        else:  # Smallest dot
            dot_size = max(1, size // 45)
        
        draw.ellipse([dot_x - dot_size, dot_y - dot_size,
                      dot_x + dot_size, dot_y + dot_size],
                     fill=(255, 255, 255, 220))
    
    # Add small triangle (cursor/arrow)
    triangle_x = center_x + size // 5
    triangle_y = center_y - size // 8
    triangle_size = max(3, size // 30)
    
    triangle_points = [
        (triangle_x, triangle_y - triangle_size),  # top
        (triangle_x - triangle_size//2, triangle_y + triangle_size//2),  # bottom left
        (triangle_x + triangle_size//2, triangle_y + triangle_size//2)   # bottom right
    ]
    draw.polygon(triangle_points, fill=(255, 255, 255, 255))
    
    return img

def create_menu_bar_icon(size):
    """Create a simplified feather for menu bar"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    center_x, center_y = size // 2, size // 2
    feather_height = size // 1.6
    feather_width = feather_height // 3
    
    # Simple feather outline for menu bar
    feather_x = center_x - size // 8
    feather_y = center_y
    
    # Feather shaft
    shaft_start_x = feather_x
    shaft_start_y = feather_y + feather_height // 2
    shaft_end_x = feather_x + feather_height // 8
    shaft_end_y = feather_y - feather_height // 2
    
    shaft_width = max(1, size // 12)
    draw.line([(shaft_start_x, shaft_start_y), (shaft_end_x, shaft_end_y)], 
              fill=(255, 255, 255, 255), width=shaft_width)
    
    # Simplified feather vane
    vane_points = []
    for i in range(6):
        progress = i / 5.0
        offset_y = feather_y - feather_height // 2 + (feather_height * progress)
        
        # Left side
        left_x = feather_x - int(feather_width * math.sin(progress * math.pi) * 0.6)
        vane_points.append((left_x, offset_y))
    
    # Right side
    for i in range(6):
        progress = (5-i) / 5.0
        offset_y = feather_y - feather_height // 2 + (feather_height * progress)
        
        right_x = feather_x + int(feather_width * math.sin(progress * math.pi) * 0.3) + feather_height // 12
        vane_points.append((right_x, offset_y))
    
    draw.polygon(vane_points, fill=(255, 255, 255, 255))
    
    # Small dots for menu bar
    dot_positions = [
        (center_x + size // 4, center_y - size // 12),
        (center_x + size // 5, center_y + size // 8)
    ]
    
    for dot_x, dot_y in dot_positions:
        dot_size = max(1, size // 16)
        draw.ellipse([dot_x - dot_size, dot_y - dot_size,
                      dot_x + dot_size, dot_y + dot_size],
                     fill=(255, 255, 255, 255))
    
    return img

# Create all required icon sizes
sizes = [16, 32, 64, 128, 256, 512, 1024]
icon_dir = "Promptify/Assets.xcassets/AppIcon.appiconset"

print(f"Creating icons in: {icon_dir}")

# Ensure directory exists
os.makedirs(icon_dir, exist_ok=True)

# Create standard app icons
for size in sizes:
    print(f"Creating icon {size}x{size}...")
    icon = create_icon(size)
    
    # Save 1x versions
    filename = f"{icon_dir}/icon_{size}x{size}.png"
    icon.save(filename)
    print(f"Saved: {filename}")
    
    # Save 2x versions for smaller sizes
    if size <= 512:
        print(f"Creating icon {size}x{size}@2x...")
        icon_2x = create_icon(size * 2)
        filename_2x = f"{icon_dir}/icon_{size}x{size}@2x.png"
        icon_2x.save(filename_2x)
        print(f"Saved: {filename_2x}")

# Update menu bar icons
menu_icon_dir = "Promptify/Assets.xcassets"
menu_iconset_dir = f"{menu_icon_dir}/MenuBarIcon.imageset"
print(f"Creating menu bar icons in: {menu_iconset_dir}")
os.makedirs(menu_iconset_dir, exist_ok=True)

# Create menu bar icon sizes
menu_icon = create_menu_bar_icon(16)
menu_icon.save(f"{menu_iconset_dir}/menubar_16.png")

menu_icon_2x = create_menu_bar_icon(32)
menu_icon_2x.save(f"{menu_iconset_dir}/menubar_16@2x.png")

menu_icon_3x = create_menu_bar_icon(48)
menu_icon_3x.save(f"{menu_iconset_dir}/menubar_16@3x.png")

print("Beautiful feather-based icons created successfully!")
print("\nFiles created:")
print(f"- App icons: {len(os.listdir(icon_dir))} files")
print(f"- Menu bar icons: {len(os.listdir(menu_iconset_dir))} files")