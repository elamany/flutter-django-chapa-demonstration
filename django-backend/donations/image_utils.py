from io import BytesIO

from PIL import Image, ImageOps
from django.core.files.base import ContentFile
import uuid

def process_image(
    uploaded_file,
    max_width=1600,
    max_height=1600,
    quality=85,
    max_file_size=5 * 1024 * 1024,
):
    """
    Process an uploaded image.

    - Validates that the file is a real image.
    - Corrects EXIF orientation.
    - Resizes while preserving aspect ratio.
    - Converts the image to WebP.
    """

    if uploaded_file.size > max_file_size:
        raise ValueError(
            "Image file size must not exceed 5 MB."
        )
    
    # Open the uploaded image
    try:
        image = Image.open(uploaded_file)
        image.verify()
    except Exception:
        raise ValueError("Uploaded file is not a valid image.")

    # Reset file position after verify()
    uploaded_file.seek(0)

    # Open again for processing
    image = Image.open(uploaded_file)

    # Correct EXIF orientation
    image = ImageOps.exif_transpose(image)

    # Resize while preserving aspect ratio
    image.thumbnail(
        (max_width, max_height),
        Image.Resampling.LANCZOS
    )

    # WebP does not handle every image mode the same way.
    # Convert unusual modes to RGB.
    if image.mode not in ("RGB", "RGBA"):
        image = image.convert("RGB")

    # Save processed image into memory
    output = BytesIO()

    image.save(
        output,
        format="WEBP",
        quality=quality,
        optimize=True,
    )

    output.seek(0)

    filename = f"{uuid.uuid4()}.webp"

    processed_file = ContentFile(
        output.read(),
        name=filename
    )

    return processed_file